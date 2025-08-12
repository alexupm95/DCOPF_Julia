# DCOPF_Julia
This code build and solve the DC Optimal Power Flow using JuMP (Julia for Mathematical Programming).

To run the code and change the input parameters, use the file "main.jl"

The code stores Input Data in mutable Structs. Some of the Output Data is also saved in mutable Structs.

To install the required Julia packages, run:

```julia
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
