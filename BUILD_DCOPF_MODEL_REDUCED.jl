# Function to build the AC OPF model
function Make_DCOPF_Model!(model::Model, 
    DBUS::DBUS_Struct, 
    DGEN::DGEN_Struct, 
    DCIR::DCIR_Struct, 
    bus_gen_circ_dict::OrderedDict,
    base_MVA::Float64, 
    nBUS::Int64, 
    nGEN::Int64, 
    nCIR::Int64)

    """
    This function builds a general AC OPF Model with the objective function, variables and constraints
    """
    #---------------------------------------------
    # Get some variables associated with the buses
    #---------------------------------------------
    P_d  = deepcopy(DBUS.p_d) ./ base_MVA  # Active power demanded by the loads     [p.u.]
    g_sh = deepcopy(DBUS.g_sh) ./ base_MVA # Shunt conductance connected to the bus [p.u.]

    #------------------------------------------
    # Check if there is at least one swing bus
    #------------------------------------------
    SW = findall(x -> x == 3, DBUS.type)
    if isempty(SW) 
        throw(ArgumentError("You must define one bus as the SLACK BUS (type 3).")) 
    elseif length(SW) > 1 
        throw(ArgumentError("This code still does not support more than one SLACK BUS (type 3).")) 
    end

    #--------------------------------------------------------------------------
    # Defining dictionaries to save everything related to the optmization model
    #--------------------------------------------------------------------------
    model.ext[:objective]        = OrderedDict{Symbol, Any}() # Objective

    # ========================================================================
    #              DEFINE THE VARIABLES OF THE MODEL
    # ========================================================================

    #-------------------------------------------------------------------------
    #                                Buses
    #-------------------------------------------------------------------------

    V = OrderedDict{Int, Float64}()
    θ = OrderedDict{Int, JuMP.VariableRef}()

    for i in eachindex(DBUS.bus)
        V[i] = 1.0                   # Constant -> Voltage magnitude of buses [p.u.]

        θ[i] = JuMP.@variable(model,
        base_name = "θ[$i]"          # Variable name -> Voltage magnitude of buses [p.u.]
        )

    end

    #-------------------------------------------------------------------------
    #                            Generators
    #-------------------------------------------------------------------------

    P_g = OrderedDict{Int, JuMP.VariableRef}()

    for i in 1:nGEN
        if DGEN.g_status[i] == 1
            P_g[i] = @variable(model,
                lower_bound = DGEN.pg_min[i] / base_MVA, # Lower Bounds
                upper_bound = DGEN.pg_max[i] / base_MVA, # Upper Bounds
                base_name = "P_g[$i]"
            )
        end
    end
  
    #-------------------------------------------------------------------------
    #                                Branches
    #-------------------------------------------------------------------------

    # Check if the circuits have capacity/thermal limits defined in the input data
    all_cap           = [DCIR.l_cap_1 DCIR.l_cap_2 DCIR.l_cap_3] # Matrix containing all three capacity limits defined in the input data file
    lower_bounds_circ = OrderedDict{Int, Float64}()                     # Dictionary to save lower bounds of capacity limits for circuits if it is defined in the input data file
    upper_bounds_circ = OrderedDict{Int, Float64}()                     # Dictionary to save upper bounds of capacity limits for circuits if it is defined in the input data file

    # Loop to check if the branch has at least one capacity limit defined in the input data file
    # If not defined, the power flow through the branch has no bounds
    for i in 1:nCIR
        if any(!iszero, all_cap[i, :])  # Line ON or OFF and has capacity
            index_cap = findfirst(!iszero, all_cap[i, :])
            cap = all_cap[i, index_cap]
            lower_bounds_circ[i] = -cap / base_MVA # Lower Bounds
            upper_bounds_circ[i] =  cap / base_MVA # Upper Bounds
        end
    end

    P_ik = OrderedDict{Int, JuMP.VariableRef}()
    P_ki = OrderedDict{Int, JuMP.VariableRef}()

    for i in 1:nCIR
        from_bus = DCIR.from_bus[i]
        to_bus   = DCIR.to_bus[i]
        if DCIR.l_status[i] == 1
            P_ik[i] = @variable(model,
                lower_bound = get(lower_bounds_circ, i, -Inf), # Lower Bounds 
                upper_bound = get(upper_bounds_circ, i, Inf),  # Upper Bounds 
                base_name = "P_ik[$i, $from_bus, $to_bus]"
            )

            P_ki[i] = @variable(model,
                lower_bound = get(lower_bounds_circ, i, -Inf), # Lower Bounds
                upper_bound = get(upper_bounds_circ, i, Inf),  # Upper Bounds
                base_name = "P_ki[$i, $to_bus, $from_bus]",
            )

        end
    end
    
    # ========================================================================
    #            DEFINE THE OBJECTIVE FUNCTION OF THE MODEL
    # ========================================================================
    # Minimize total fuel cost

    total_cost = 0.0  # Start from zero

    for gen in 1:nGEN
        if DGEN.g_status[gen] == 1 && haskey(P_g, gen)
            if DGEN.g_cost_0[gen] != 0.0
                total_cost += DGEN.g_cost_0[gen]
            end
            if DGEN.g_cost_1[gen] != 0.0
                total_cost += DGEN.g_cost_1[gen] * P_g[gen] * base_MVA
            end
            if DGEN.g_cost_2[gen] != 0.0
                total_cost += DGEN.g_cost_2[gen] * (P_g[gen] * base_MVA)^2
            end
        end
    end

    model.ext[:objective] = @objective(model, Min, total_cost)
    
    # ========================================================================
    #            DEFINE THE CONSTRAINTS OF THE MODEL
    # ========================================================================

    #-------------------------------------------------------------------------
    #                  Equality and Inequality Constraints 
    #-------------------------------------------------------------------------

    # *********************************
    # Constraint for angle of swing bus
    # *********************************
    eq_const_angle_sw = OrderedDict{Int, JuMP.ConstraintRef}()

    if any(bus_gen_circ_dict[SW[1]][:gen_status] .== 1)                          # First check if the swing bus has at least one generator connected to it
        eq_const_angle_sw = JuMP.@constraint(model, θ[DBUS.bus[SW[1]]] == 0.0)   # Set the constraint -> Angle == 0
    else
        throw(ArgumentError("Swing bus $(SW[1]) must have at least one connected generator with status ON.")) # Throw an error if the swing bus has no generator connected to it
    end

    # Create expressions for the inflow/outflow of power in all buses according to the model variables
    p_flow_terms_dict = OrderedDict{Int, Vector{JuMP.GenericAffExpr{Float64, JuMP.VariableRef}}}() # Dictionary of active power inflow/outflow

    for bus in DBUS.bus # Loop in all buses
        terms_p = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}[]  # List of expressions

        indices_circ_connected = bus_gen_circ_dict[bus][:circ]    # Circuits connected to bus i
        if isempty(indices_circ_connected)
            throw(ArgumentError("The bus $bus is islanded, i.e., there is no line or transformer connected to it."))
        end

        for (i, f_bus) in enumerate(DCIR.from_bus)
            t_bus = DCIR.to_bus[i]
            if DCIR.l_status[i] == 1
                if f_bus == bus
                    push!(terms_p, P_ik[i])  # Power flows out of bus
                elseif t_bus == bus
                    push!(terms_p, P_ki[i])  # Power flows into bus
                end
            end
        end
        p_flow_terms_dict[bus] = terms_p
    end
   
    # ************************************
    # Constraints for Active Power Balance
    # ************************************
    eq_const_p_balance = OrderedDict{Int, JuMP.ConstraintRef}()

    for i in 1:nBUS
        indices_bus_gen        = bus_gen_circ_dict[i][:gen_ids] # Generators at bus i
        indices_circ_connected = bus_gen_circ_dict[i][:circ]    # Circuits connected to bus i
        terms_p                = p_flow_terms_dict[i]           # Active power flow terms

        if isempty(indices_circ_connected) # Check if the bus has at least one branch connected to it
            throw(ArgumentError("The bus $i is islanded, i.e., there is no line or transformer connected to it."))
        end

        # Get generator variables from the dictionary for those ON at this bus
        Pg_terms = [P_g[g] for g in indices_bus_gen if haskey(P_g, g)]

        Pg_sum = isempty(Pg_terms) ? 0.0 : sum(Pg_terms) # Sum P_g terms; zero otherwise

        if g_sh[i] == 0.0 # Check if the bus has shunt elements connected to it 
            eq_const_p_balance[i] = @constraint(model, sum(terms_p) == Pg_sum - P_d[i])

        else
            eq_const_p_balance[i] = @constraint(model, sum(terms_p) == Pg_sum - P_d[i] - g_sh[i] * V[i]^2)
        end
    end

    eq_const_p_ik   = OrderedDict{Int, JuMP.ConstraintRef}() # Dict to save equality constraints of active power flow from bus i to bus k
    eq_const_p_ki   = OrderedDict{Int, JuMP.ConstraintRef}() # Dict to save equality constraints of active power flow from bus k to bus i

    # Loop in all branches
    for lin = 1:nCIR
        if DCIR.l_status[lin] == 1 # Check if the branch is ON

            i       = DCIR.from_bus[lin]                           # Bus i (from)
            k       = DCIR.to_bus[lin]                             # Bus k (to)

            b     = 1 / (DCIR.l_reac[lin]) # Branch series susceptance                   

            angik   = θ[i] - θ[k]                                  # Angular difference between bus i and k
            angki   = θ[k] - θ[i]                                  # Angular difference between bus k and i

            # ***************************************************
            # Equality Constraints for power flow in the branches
            # ***************************************************

            # Line flow from i to k
            eq_const_p_ik[lin] = JuMP.@constraint(model, P_ik[lin] == b * angik)

            # Line flow from k to i
            eq_const_p_ki[lin] = JuMP.@constraint(model, P_ki[lin] == b * angki)
         
        end
    end

    # Initialize dictionary with count, min_ang, max_ang
    pair_info = Dict{Tuple{Int, Int}, NamedTuple{(:count, :min_ang, :max_ang), Tuple{Int, Float64, Float64}}}()
    pair_circ_map = Dict{Tuple{Int, Int}, Int}()

    # This loop maps the circuits that have parallel branches, count the number of parallel lines/transformers,
    # and save the minimum and maximum angular difference for the buses related to these circuits
    for i in 1:nCIR
        if DCIR.l_status[i] == 1                     # Only consider active branches
            a, b = DCIR.from_bus[i], DCIR.to_bus[i]  # Bus from and bus to
            pair = (min(a, b), max(a, b))            # Sort the buses id
            circ_num = DCIR.circ[i]                  # Get the number of the branch


            if !haskey(pair_circ_map, pair)          # Check if these buses were already addded
                pair_circ_map[pair] = circ_num       # Get only the number of the first branch ON connecting these buses
            else
                pair_circ_map[pair] = min(pair_circ_map[pair], circ_num) # Get the number of the first branch ON connecting these buses
            end
            
            if haskey(pair_info, pair) # Check if this pair of buses were already added
                # Update count
                old       = pair_info[pair]
                new_count = old.count + 1                       # Count the number of branches ON connecting these buses
                new_min   = min(old.min_ang, DCIR.ang_min[i])   # Get the minimum angle defined for the branches connecting these buses
                new_max   = max(old.max_ang, DCIR.ang_max[i])   # Get the maximum angle defined for the branches connecting these buses
                pair_info[pair] = (new_count, new_min, new_max)
            else
                pair_info[pair] = (1, DCIR.ang_min[i], DCIR.ang_max[i]) # Add this pair of buses for the first time
            end
        end
    end
    sorted_pair_info  = sort(collect(pair_info), by = x -> pair_circ_map[x[1]]) # Sort the data inside pair_info Dict

    ineq_const_diff_ang  = OrderedDict{Int, JuMP.ConstraintRef}() # Vector to save inequality constraints of angle difference between adjacent buses

    for (pair, pair_data) in sorted_pair_info
        bus_from, bus_to = pair
        ang_ik = θ[bus_from] - θ[bus_to]

        circ_id = pair_circ_map[pair]

        min_ang = pair_data.min_ang
        max_ang = pair_data.max_ang

        # ***************************************************
        # Inequality Constraint for voltage angle differences
        # ***************************************************
        if min_ang >= -30 && max_ang <= 30 
            ineq_const_diff_ang[circ_id] = JuMP.@constraint(model, deg2rad(min_ang) <= ang_ik <= deg2rad(max_ang))

        elseif min_ang < -30 && max_ang <= 30
            println("Correcting angle constraints between adjacent buses ($bus_from, $bus_to): setting ang_min to -30°.")
            ineq_const_diff_ang[circ_id] = JuMP.@constraint(model, deg2rad(-30) <= ang_ik <= deg2rad(max_ang))

        elseif min_ang >= -30 && max_ang > 30
            println("Correcting angle constraints between adjacent buses ($bus_from, $bus_to): setting ang_max to +30°.")
            ineq_const_diff_ang[circ_id] = JuMP.@constraint(model, deg2rad(min_ang) <= ang_ik <= deg2rad(30))

        else # min_ang < -30 && max_ang > 30
            println("Correcting angle constraints between adjacent buses ($bus_from, $bus_to): setting ang_min to -30° and ang_max to +30°.")
            ineq_const_diff_ang[circ_id] = JuMP.@constraint(model, deg2rad(-30) <= ang_ik <= deg2rad(30))
        end
    end

    return model, V, θ, P_g, P_ik, P_ki, eq_const_angle_sw, eq_const_p_balance, eq_const_p_ik, eq_const_p_ki, ineq_const_diff_ang # Return the model to the main function
end
