# DCOPF_Julia
This code build and solve the DC Optimal Power Flow using JuMP (Julia for Mathematical Programming).

To run the code and change the input parameters, use the file "Main_DCOPF.jl"

To properly run the code, install the following packages:

using Pkg
Pkg.add("LinearAlgebra")
Pkg.add("SparseArrays")
Pkg.add("DataFrames")
Pkg.add("Printf")
Pkg.add("CSV")
Pkg.add("DataStructures")
Pkg.add("JuMP")
Pkg.add("Gurobi")
Pkg.add("Ipopt")
