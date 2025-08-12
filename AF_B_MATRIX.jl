function Calculate_Matrix_B(DBUS::DBUS_Struct, DCIR::DCIR_Struct, nBUS::Int64, nCIR::Int64)
    # DBUS is the array related to the bus data
    # DCIR is the array related to the circuit data
    # nBUS is the number of buses
    # nCIR is the number of circuits

    # From the terminal nodes of each line (from_bus and to_bus), we create the incidence matrix,
    # where we assign 1 to from_bus nodes and -1 to to_bus nodes.
    # For the sparse function in SparseArrays, the arguments are:
    # sparse([Row Indices], [Column Indices], [Value], [Total Number of Rows], [Total Number of Columns])
    A = SparseArrays.sparse(DCIR.from_bus[:], 1:nCIR, 1, nBUS, nCIR) + SparseArrays.sparse(DCIR.to_bus[:], 1:nCIR, -1, nBUS, nCIR)

    # Create a vector with the susceptance values of each line B = -1/x
    B = @. - DCIR.l_status[:] / (DCIR.l_reac[:])
    # B = @. - (DCIR.l_status[:] * DCIR.l_reac[:]) / (DCIR.l_res[:]^2 + DCIR.l_reac[:]^2)

    # Once we have the Incidence Matrix "A" and the Susceptance vector "B",
    # we can construct the Susceptance Matrix "B_0":
    B_0 = A * SparseArrays.spdiagm(B) * A'
    # Here, spdiagm creates a sparse matrix and assigns the elements of vector B to the main diagonal

    # Return the susceptance matrix
    return B_0
end

# Function to calculate the Inverse of the Susceptance Matrix using Sparsity techniques
function Calculate_Inverse_Matrix_B(B::SparseMatrixCSC, nBUS::Int64, ref_bus::Int64)
    S  = deepcopy(B)

    if !(ref_bus > 0 && ref_bus <= nBUS)
        Memento.error(_LOGGER, "invalid ref_bus in calc_susceptance_matrix_inv")
    end

    S[ref_bus, :] .= 0.0
    S[:, ref_bus] .= 0.0
    S[ref_bus, ref_bus] = 1.0
    
    F = LinearAlgebra.ldlt(Symmetric(S); check=false)

    if !LinearAlgebra.issuccess(F)
        Memento.error(_LOGGER, "Failed factorization in calc_susceptance_matrix_inv")
    end

    B_inv = F \ Matrix(1.0I, nBUS, nBUS)
    B_inv[ref_bus, :] .= 0.0  # zero-out the row of the slack bus
    
    # return Admittance Matrix Inverse
    return B_inv
end