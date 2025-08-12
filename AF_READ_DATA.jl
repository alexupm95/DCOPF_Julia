# Function used to Read the Input data from the CSV files and store them into Structs
function Read_Input_Data(folder_path::String)

    # ====================================================================================================
    # If some modification is done in the name of the variables in the CSV files, it must be modified here
    # ==================================================================================================== 

    # Function to read buses data and store in DBUS_Struct
    function read_bus_data()
        df = CSV.read("bus_data.csv", DataFrame; delim=';')  # Read CSV file
        return DBUS_Struct(
            Vector{Int64}(df.bus_i),
            Vector{Int64}(df.type),
            Vector{Float64}(df.Pd),
            Vector{Float64}(df.Qd),
            Vector{Float64}(df.Gs),
            Vector{Float64}(df.Bs),
            Vector{Int64}(df.area),
            Vector{Float64}(df.Vm),
            Vector{Float64}(df.Va),
            Vector{Float64}(df.baseKV),
            Vector{Int64}(df.zone),
            Vector{Float64}(df.Vmax),
            Vector{Float64}(df.Vmin)
        )
    end

    # Function to read generators data and store in DGEN_Struct
    function read_gen_data()
        df = CSV.read("generators_data.csv", DataFrame; delim=';') # Read CSV file
        num_gen = length(df.bus)
        id = collect(1:num_gen)

        return DGEN_Struct(
            Vector{Int64}(id),
            Vector{Int64}(df.bus),
            Vector{Float64}(df.Pg),
            Vector{Float64}(df.Qg),
            Vector{Float64}(df.Qmax),
            Vector{Float64}(df.Qmin),
            Vector{Float64}(df.Vg),
            Vector{Float64}(df.mBase),
            Vector{Int64}(df.status),
            Vector{Float64}(df.Pmax),
            Vector{Float64}(df.Pmin),
            Vector{Float64}(df.c2),
            Vector{Float64}(df.c1),
            Vector{Float64}(df.c0)
        )
    end

    # Function to read circuits data and store in DCIR_Struct
    function read_circuit_data()
        df = CSV.read("line_data.csv", DataFrame; delim=';')
        num_circ = length(df.fbus)
        id = collect(1:num_circ)

        return DCIR_Struct(
            Vector{Int64}(id),
            Vector{Int64}(df.fbus),
            Vector{Int64}(df.tbus),
            Vector{Float64}(df.r),
            Vector{Float64}(df.x),
            Vector{Float64}(df.b),
            Vector{Float64}(df.rateA),
            Vector{Float64}(df.rateB),
            Vector{Float64}(df.rateC),
            Vector{Float64}(df.ratio),
            Vector{Float64}(df.angle),
            Vector{Int64}(df.status),
            Vector{Float64}(df.angmin),
            Vector{Float64}(df.angmax)
        )
    end

    cd(folder_path) # Load the folder were the input data files are stored

    DBUS     = read_bus_data()          # Generate the Struct with Buses data
    DGEN     = read_gen_data()          # Generate the Struct with Generators data
    DCIR     = read_circuit_data()      # Generate the Struct with Circuits data

    # For the code to work properly, the bus indices must be set in ascending order from 1 to nBUS
    bus_mapping, reverse_bus_mapping = Mapping_Buses_Labels(DBUS::DBUS_Struct) # Map the buses labels from old to new nomeclature
    DBUS.bus = [bus_mapping[b] for b in DBUS.bus]                              # Rename the buses labels from 1 to nBUS

    # Map the buses labels to be in ascending order from 1 to nBUS
    DGEN.bus      = [bus_mapping[b] for b in DGEN.bus]
    DCIR.from_bus = [bus_mapping[b] for b in DCIR.from_bus]
    DCIR.to_bus   = [bus_mapping[b] for b in DCIR.to_bus]

    return DBUS, DGEN, DCIR, bus_mapping, reverse_bus_mapping # Return the data
end

# Function used to map the from old to new nomeclature
function Mapping_Buses_Labels(DBUS::DBUS_Struct)

    # Given bus numbers
    original_buses = DBUS.bus

    # Create a dictionary that maps original bus labels to new indices
    bus_mapping = OrderedDict(original_buses[i] => i for i in eachindex(original_buses))

    # Reverse mapping (for converting back later)
    reverse_bus_mapping = OrderedDict(i => original_buses[i] for i in eachindex(original_buses))

    return bus_mapping, reverse_bus_mapping
end

# Function that can change the buses labels according to the new nomenclature
function Change_Buses_Labels(DBUS::DBUS_Struct, DGEN::DGEN_Struct, DCIR::DCIR_Struct, bus_mapping::OrderedDict)
    
    # Convert using the reverse mapping
    DBUS.bus      = [bus_mapping[b] for b in DBUS.bus]
    DGEN.bus      = [bus_mapping[b] for b in DGEN.bus]
    DCIR.from_bus = [bus_mapping[b] for b in DCIR.from_bus]
    DCIR.to_bus   = [bus_mapping[b] for b in DCIR.to_bus]

    return DBUS, DGEN, DCIR
end

# Function that can return the buses labels according to the original nomenclature
function Reverse_Buses_Labels(DBUS::DBUS_Struct, DGEN::DGEN_Struct, DCIR::DCIR_Struct, reverse_bus_mapping::OrderedDict)
        
    # Convert using the reverse mapping
    DBUS.bus      = [reverse_bus_mapping[b] for b in DBUS.bus]
    DGEN.bus      = [reverse_bus_mapping[b] for b in DGEN.bus]
    DCIR.from_bus = [reverse_bus_mapping[b] for b in DCIR.from_bus]
    DCIR.to_bus   = [reverse_bus_mapping[b] for b in DCIR.to_bus]

    return DBUS, DGEN, DCIR
end
