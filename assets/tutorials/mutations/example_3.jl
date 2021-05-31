using FLoops

@floop for (A, B) in zip(As, Bs)
    C = A * B             # allocation for each iteration
    @reduce() do (S = zero(C); C)
        S = S + C         # allocation for each iteration
    end
end
