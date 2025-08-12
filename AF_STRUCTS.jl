
"""
Structs to save the input and output data
"""
# =============================
#          BUS DATA
# =============================
mutable struct DBUS_Struct
    bus::Vector{Int64}        # Bus number
    type::Vector{Int64}       # Bus type: (3 = SW), (2 = PV) or (1 = PQ)
    p_d::Vector{Float64}      # Active power demanded (p.u)
    q_d::Vector{Float64}      # Reactive power demanded (p.u)
    g_sh::Vector{Float64}     # Shunt conductance (p.u)
    b_sh::Vector{Float64}     # Shunt susceptance (p.u)
    area::Vector{Int64}       # Area where the bus is located
    v_spe::Vector{Float64}    # Voltage specified (p.u)
    v_a::Vector{Float64}      # Voltage angles (p.u)
    base_kV::Vector{Float64}  # Base voltage of the system (kV)
    zone::Vector{Int64}       # Zone where the bus is located
    v_max::Vector{Float64}    # Maximum bus voltage (p.u)
    v_min::Vector{Float64}    # Minimum bus voltage (p.u)

    function DBUS_Struct(bus, type, p_d, q_d, g_sh, b_sh, area, v_spe, v_a, base_kV, zone, v_max, v_min)
        new(bus, type, p_d, q_d, g_sh, b_sh, area, v_spe, v_a, base_kV, zone, v_max, v_min)
    end
end

# =============================
#        GENERATOR DATA
# =============================
mutable struct DGEN_Struct
    id::Vector{Int64}          # Generator identifier
    bus::Vector{Int64}         # Bus number
    pg_spe::Vector{Float64}    # Active power for generation specified (MW)
    qg_spe::Vector{Float64}    # Reactive power for generation specified (MVAr)
    qg_max::Vector{Float64}    # Maximum reactive power capacity (MVAr)
    qg_min::Vector{Float64}    # Minimum reactive power capacity (MVAr)
    vg_spe::Vector{Float64}    # Voltage specified for the generator (p.u)
    base_MVA::Vector{Float64}  # Base power of the system (MVA)
    g_status::Vector{Int64}    # Generator status
    pg_max::Vector{Float64}    # Maximum active power capacity (MW)
    pg_min::Vector{Float64}    # Minimum active power capacity (MW)
    g_cost_2::Vector{Float64}  # Generation cost (quadratic) (€/MW)
    g_cost_1::Vector{Float64}  # Generation cost (linear) (€/MW)
    g_cost_0::Vector{Float64}  # Generation cost (fixed) (€/MW)

    function DGEN_Struct(id, bus, pg_spe, qg_spe, qg_max, qg_min, vg_spe, base_MVA, g_status, pg_max, pg_min, g_cost_0, g_cost_1, g_cost_2)
        return new(id, bus, pg_spe, qg_spe, qg_max, qg_min, vg_spe, base_MVA, g_status, pg_max, pg_min, g_cost_0, g_cost_1, g_cost_2)
    end
end

# =============================
#        CIRCUIT DATA
# =============================
mutable struct DCIR_Struct
    circ::Vector{Int64}        # Circuit identifier
    from_bus::Vector{Int64}    # "From" bus
    to_bus::Vector{Int64}      # "To" bus
    l_res::Vector{Float64}     # Line resistance (p.u)
    l_reac::Vector{Float64}    # Line reactance (p.u)
    l_sh_susp::Vector{Float64} # Line shunt susceptance (Π model) (p.u)
    l_cap_1::Vector{Float64}   # Line maximum capacity 1 (MW or MVA)
    l_cap_2::Vector{Float64}   # Line maximum capacity 2 (MW or MVA)
    l_cap_3::Vector{Float64}   # Line maximum capacity 3 (MW or MVA)
    t_tap::Vector{Float64}     # Transformer tap (p.u)
    t_shift::Vector{Float64}   # Shift angle of the transformer (degrees)
    l_status::Vector{Int64}    # Line ON or line OFF
    ang_min::Vector{Float64}   # Minimum angle (degrees)
    ang_max::Vector{Float64}   # Maximum angle (degrees)

    function DCIR_Struct(circ, from_bus, to_bus, l_res, l_reac, l_sh_susp, l_cap_1, l_cap_2, l_cap_3, t_tap, t_shift, l_status, ang_min, ang_max)
        new(circ, from_bus, to_bus, l_res, l_reac, l_sh_susp, l_cap_1, l_cap_2, l_cap_3, t_tap, t_shift, l_status, ang_min, ang_max)
    end
end
# ##############################

"""
Structs to save the output data
"""
# ==============================
# REPORT OF BUS OUTPUT VARIABLES
# ==============================
mutable struct RBUS_Struct
    bus::Vector{Int64}        # Bus number
    v::Vector{Float64}        # Voltage (pu)
    θ::Vector{Float64}        # Angle (º)
    p::Vector{Float64}        # Net active power (MW)
    q::Vector{Float64}        # Net reactive power (MVAr)
    p_g::Vector{Float64}      # Active power generated (MW)
    q_g::Vector{Float64}      # Reactive power generated (MW)
    p_d::Vector{Float64}      # Active power demanded (MW)
    q_d::Vector{Float64}      # Reactive power demanded (MW)
    p_sh::Vector{Float64}     # Active power demanded by the shunt element (MW)
    q_sh::Vector{Float64}     # Rective power demanded by the shunt element (MW)

    function RBUS_Struct(bus, v, θ, p, q, p_g, q_g, p_d, q_d, p_sh, q_sh)
        new(bus, v, θ, p, q, p_g, q_g, p_d, q_d, p_sh, q_sh)
    end
end

# ==================================
# REPORT OF CIRCUIT OUTPUT VARIABLES
# ==================================
mutable struct RCIR_Struct
    circ::Vector{Int64}       # Circuit ID
    from_bus::Vector{Int64}   # "From" bus
    to_bus::Vector{Int64}     # "To" bus
    p_ik::Vector{Float64}     # Active power flow from bus i to bus k (MW)
    q_ik::Vector{Float64}     # Rective power flow from bus i to bus k (MVar)
    s_ik::Vector{Float64}     # Apparent power flow from bus i to bus k (MVA)
    p_ki::Vector{Float64}     # Active power flow from bus k to bus i (MW)
    q_ki::Vector{Float64}     # Reactive power flow from bus k to bus i (MVar)
    s_ki::Vector{Float64}     # Apparent power flow from bus k to bus i (MVA)
    p_losses::Vector{Float64} # Losses of active power (MW)
    q_losses::Vector{Float64} # Losses of reactive power (MVAr)
    s_cap::Vector{Float64}    # Maximum capacity of apparent power flow (MVA)
    loading::Vector{Float64}  # Circuit loading (between 0 and 1 according to its capacity)

    function RCIR_Struct(circ, from_bus, to_bus, p_ik, q_ik, s_ik, p_ki, q_ki, s_ki, p_losses, q_losses, s_cap, loading)
        new(circ, from_bus, to_bus, p_ik, q_ik, s_ik, p_ki, q_ki, s_ki, p_losses, q_losses, s_cap, loading)
    end
end

# ====================================
# REPORT OF GENERATOR OUTPUT VARIABLES
# ====================================
mutable struct RGEN_Struct
    id_gen::Vector{Int64}       # Generator identifier
    id_bus::Vector{Int64}       # Bus identifier
    p_g::Vector{Float64}        # Active power (MW)
    q_g::Vector{Float64}        # Reactive power (MVAr)
    s_g::Vector{Float64}        # Apparent power (MVA)
    loading_p::Vector{Float64}  # Generator loading (between 0 and 1 according to its capacity of active power)
    loading_q::Vector{Float64}  # Generator loading (between 0 and 1 according to its capacity of reactive power)

    function RGEN_Struct(id_gen, id_bus, p_g, q_g, s_g, loading_p, loading_q)
        new(id_gen, id_bus, p_g, q_g, s_g, loading_p, loading_q)
    end
end
