using FLoops
using LinearAlgebra: mul!

@floop for (A, B) in zip(As, Bs)
    C = (A, B)
    @reduce() do (S = zero(A); C)
        if C isa Tuple  # base case
            mul!(S, C[1], C[2], 1, 1)
        else            # combining base cases
            S .+= C
        end
    end
end
