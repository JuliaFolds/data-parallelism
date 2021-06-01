vectors = Any[[n n^2; n^3 n^4] for n in 1:100]
@floop for xs in vectors
    @reduce() do (ys = nothing; xs)
        if ys === nothing
            ys = xs  # ❌ WRONG
        else
            ys .+= xs
        end
    end
end

@assert ys === vectors[1]  # above loop mutated the input
