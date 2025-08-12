cd(dirname(@__FILE__));

#=
CODE TO SOLVE THE DC OPTIMAL POWER FLOW

Author:      Alex Junior da Cunha Coelho
Supervisors: Luis Badesa Bernardo and Araceli Hernandez Bayo
Affiliation: Technical University of Madrid
August 2025

===================================================================
                        IMPORTANT NOTES 
===================================================================
Series reactance of transmission lines and transformers are considered
Shunt conductances at the buses are also considered 
=#

#---------------------------
# INCLUDE THE PACKAGES USED
#---------------------------
# Packages related to linear algebra
using LinearAlgebra, SparseArrays

# Packages related to treatement of data
using Dates, NumericIO, DataFrames, Printf, CSV, DataStructures

# Packages related to the optimization
using JuMP, Gurobi, Ipopt

#---------------------------------
# INCLUDE AUXILIAR FUNCTION FILES
#--------------------------------
include("AF_CLEAN_TERMINAL.jl")         # Auxiliar function to clean the terminal
include("AF_STRUCTS.jl")                # Auxiliar functions to generate structs
include("AF_READ_DATA.jl")              # Auxiliar functions used to read input data
include("AF_B_MATRIX.jl")               # Auxiliar function to create the Suscpetance Matrix
include("BUILD_DCOPF_MODEL_REDUCED.jl") # Auxiliar function to create the AC OPF model for optimization (this creates a reduced version neglecting OFF components)
include("AF_SAVE_OUTPUT.jl")            # Auxiliar function to save the output results
include("AF_MANAGEMENT.jl")             # Auxiliar function that calculates AC power flow and manage some data

Clean_Terminal() # Clean the terminal

#-----------------------------------------
# Generate a folder to export the results
#-----------------------------------------
current_path_folder = pwd()                                            # Directory of the current folder
name_path_results   = "Results"                                        # Name of the folder to save the results (it must be created in advance)
path_folder_results = joinpath(current_path_folder, name_path_results) # Results directory
cd(current_path_folder)                                                # Load the current folder

#=
----------------------------------------------
 Relevant input variables to solve the AC-OPF
----------------------------------------------
** Select a system from the options below: **
3bus
9bus
CasoValidacion
EjemploTwitter_kyrib
EjemploTwitter_kyrib_2
pglib_opf_case30_as
pglib_opf_case39_epri
pglib_opf_case179_goc
pglib_opf_case300_ieee
pglib_opf_case2383wp_k
Simple2N
=#

case     = "pglib_opf_case39_epri" # Case under study (folder name)
base_MVA = 100.0  # Base Power [MVA]

#------------------------------------------
# Call the function to read the input data
#------------------------------------------
input_data_path_folder = joinpath(current_path_folder, "Input_Data", case) # Folder name where the input data is located
# Get the structs with data related to buses, generators and circuits
DBUS, DGEN, DCIR, bus_mapping, reverse_bus_mapping = Read_Input_Data(input_data_path_folder) 

nBUS = length(DBUS.bus)      # Number of buses in the system
nGEN = length(DGEN.id)       # Number of generators in the system
nCIR = length(DCIR.from_bus) # Number of circuits in the system
cd(current_path_folder)      # Load the current folder

# ------------------
# Some sanity checks
# ------------------
if !(haskey(bus_mapping, bus_fault))
    throw(ArgumentError("The ID of the faulted bus does not exist in the CSV of input data."))
end

if maximum(circ_trip) > nCIR
    throw(ArgumentError("The IDs of the faulted circuits are greater than the ids in DCIR."))
end

#-------------------------------------------------------------------------------------------------
# Associates the buses with the generators and circuits connected to it, as well as adjacent buses
#-------------------------------------------------------------------------------------------------
bus_gen_circ_dict, bus_gen_circ_dict_ON = Manage_Bus_Gen_Circ(DBUS, DGEN, DCIR) 

#-----------------------------------
# Calculate the Susceptance Matrix
#-----------------------------------

# Calculate the Susceptance Matrix
B_matrix = Calculate_Matrix_B(DBUS, DCIR, nBUS, nCIR) # Susceptance matrix

cd(joinpath(path_folder_results,"Susceptance_Matrix"))
df_B_matrix = DataFrame(Matrix(B_matrix), :auto)        # Convert the susceptance matrix into a DataFrame to save it
CSV.write("df_B_matrix.csv", df_B_matrix; delim=';')    # Save the susceptance matrix in a CSV file

println("--------------------------------------------------------------------------------------------------------------------------------------")
println("Susceptance matrix successfully saved in: ", joinpath(path_folder_results,"Susceptance_Matrix"))
println("--------------------------------------------------------------------------------------------------------------------------------------")
cd(current_path_folder)

# ########################################################################################
#                                 STARTS OPTIMIZATION PROCESS 

#-----------------------------------
# Optimization model -> Setup
#-----------------------------------
# optimizer = Ipopt.Optimizer
optimizer = Gurobi.Optimizer
model = JuMP.Model(optimizer)
if optimizer == Ipopt.Optimizer
    JuMP.set_optimizer_attribute(model, "tol", 1e-8)
    JuMP.set_optimizer_attribute(model, "print_level", 0)
    JuMP.set_optimizer_attribute(model, "max_iter", 5000)
elseif optimizer == Gurobi.Optimizer
    JuMP.set_optimizer_attribute(model, "OptimalityTol", 1e-8)
    JuMP.set_optimizer_attribute(model, "OutputFlag", 0)
    JuMP.set_optimizer_attribute(model, "IterationLimit", 5000)
end
JuMP.set_silent(model)

#------------------------------
# Build the Optimization Model
#------------------------------
time_to_build_model = time() # Start the timer to build the Optimization Model

model, V, θ, P_g, P_ik, P_ki, eq_const_angle_sw, eq_const_p_balance, eq_const_p_ik, eq_const_p_ki, 
ineq_const_diff_ang = Make_DCOPF_Model!(model, DBUS, DGEN, DCIR, bus_gen_circ_dict_ON, base_MVA, nBUS, nGEN, nCIR)

time_to_build_model = time() - time_to_build_model # End the timer to build the Optimization Model
println("\nTime to build the model: $time_to_build_model sec\n")

# =====================================================================================

#-------------------------------------------------------------------------------------
#                         SAVE MODEL SUMMARY AND DETAILS
#-------------------------------------------------------------------------------------
println("--------------------------------------------------------------------------------------------------------------------------------------")
Export_DCOPF_Model(model, θ, P_g, P_ik, P_ki, eq_const_angle_sw, eq_const_p_balance, eq_const_p_ik, eq_const_p_ki, 
ineq_const_diff_ang, current_path_folder, path_folder_results)

println("--------------------------------------------------------------------------------------------------------------------------------------")

# ---------------------------------
#  Solve the optmization problem
# ---------------------------------
time_to_solve_model = time()                       # Start the timer to solve the Optimization Model
JuMP.optimize!(model)                              # Optimize model
time_to_solve_model = time() - time_to_solve_model # End the timer to build the Optimization Model
println("\nTime to solve the model: $time_to_solve_model sec")
status_model = JuMP.termination_status(model)
println("Termination Status: $status_model \n")
println("--------------------------------------------------------------------------------------------------------------------------------------")


#                               ENDS OPTIMIZATION PROCESS 
# ########################################################################################

RBUS::Union{Nothing, RBUS_Struct} = nothing
RGEN::Union{Nothing, RGEN_Struct} = nothing
RCIR::Union{Nothing, RCIR_Struct} = nothing

if status_model == OPTIMAL || status_model == LOCALLY_SOLVED || status_model == ITERATION_LIMIT
    #-------------------------------------------------------------------------------------
    #                             SAVE RESULTS 
    #-------------------------------------------------------------------------------------
    RBUS, RGEN, RCIR = Save_Solution_Model(model, V, θ, P_g, P_ik, P_ki, bus_gen_circ_dict_ON, 
    DBUS, DGEN, DCIR, base_MVA, nBUS, nGEN, nCIR, bus_mapping, reverse_bus_mapping, 
    current_path_folder, path_folder_results)

    #-------------------------------------------------------------------------------------
    #                             SAVE DUALS 
    #-------------------------------------------------------------------------------------
    Save_Duals_DCOPF_Model(model, P_g, P_ik, P_ki, eq_const_angle_sw, eq_const_p_balance, 
    eq_const_p_ik, eq_const_p_ki, ineq_const_diff_ang, base_MVA, current_path_folder, path_folder_results)

else
    JuMP.@warn "Optmization process failed. No feasible solution found."
end
println("--------------------------------------------------------------------------------------------------------------------------------------")
