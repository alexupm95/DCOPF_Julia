# File with auxiliary functions

# Function used to map the generators, circuits connected, and adjacent buses for each bus
function Manage_Bus_Gen_Circ(DBUS::DBUS_Struct, DGEN::DGEN_Struct, DCIR::DCIR_Struct)

    # Initialize the dictionary with empty vectors for each bus
    bus_gen_circ_dict = OrderedDict(b => Dict(:gen_ids => Int[], :gen_status => Bool[], :circ => Int[], :adj_buses => Int[], :vg_spe => 1.0) for b in DBUS.bus)

    bus_gen_circ_dict_ON = OrderedDict(b => Dict(:gen_ids => Int[], :gen_status => Bool[], :circ => Int[], :adj_buses => Int[], :vg_spe => 1.0) for b in DBUS.bus)

    # Loop through the generators and fill the dictionary
    # Associate the number of the bus with a vector containing
    # the ids of the generators
    for (gen_idx, bus_id) in enumerate(DGEN.bus)
        push!(bus_gen_circ_dict[bus_id][:gen_ids], gen_idx)
        push!(bus_gen_circ_dict[bus_id][:gen_status], DGEN.g_status[gen_idx])

        local a = unique(DGEN.vg_spe[gen_idx])
        if isempty(a)
            bus_gen_circ_dict[bus_id][:vg_spe] = 0.0
        elseif length(a) > 1
            throw(ArgumentError("The voltages specified for the generators connected to bus $bus_id must be equal."))
        else
            bus_gen_circ_dict[bus_id][:vg_spe] = a[1]
        end

        if DGEN.g_status[gen_idx] == 1
            push!(bus_gen_circ_dict_ON[bus_id][:gen_ids], gen_idx)
            push!(bus_gen_circ_dict_ON[bus_id][:gen_status], DGEN.g_status[gen_idx])
            local a = unique(DGEN.vg_spe[gen_idx])
            if isempty(a)
                bus_gen_circ_dict_ON[bus_id][:vg_spe] = 0.0
            elseif length(a) > 1
                throw(ArgumentError("The voltages specified for the generators connected to bus $bus_id must be equal."))
            else
                bus_gen_circ_dict_ON[bus_id][:vg_spe] = a[1]
            end
        end

    end

    # Loop through circuits and populate ids of circuits connectec
    # and adjacent buses
    for (i, from) in enumerate(DCIR.from_bus)
        to = DCIR.to_bus[i]
        
        # Add the number of the circuit
        push!(bus_gen_circ_dict[from][:circ], i)
        push!(bus_gen_circ_dict[to][:circ], i)

        # Add each bus as adjacent to the other
        push!(bus_gen_circ_dict[from][:adj_buses], to)
        push!(bus_gen_circ_dict[to][:adj_buses], from)

        if DCIR.l_status[i] == 1
            # Add the number of the circuit
            push!(bus_gen_circ_dict_ON[from][:circ], i)
            push!(bus_gen_circ_dict_ON[to][:circ], i)

            # Add each bus as adjacent to the other
            push!(bus_gen_circ_dict_ON[from][:adj_buses], to)
            push!(bus_gen_circ_dict_ON[to][:adj_buses], from)
        end

    end
    
    return bus_gen_circ_dict, bus_gen_circ_dict_ON
end


