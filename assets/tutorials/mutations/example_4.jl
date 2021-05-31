using LinearAlgebra: mul!

@floop for (A, B) in zip(As, Bs)
    @init C = similar(A)
    mul!(C, A, B)
    @reduce() do (S = zero(C); C)
        S .+= C
    end
end
