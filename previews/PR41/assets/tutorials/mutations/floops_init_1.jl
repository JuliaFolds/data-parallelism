using FLoops

@floop for x in 1:10
    @init xs = Vector{Int}(undef, 3)
    xs .= (x, 2x, 3x)
    @reduce() do (ys = zeros(Int, 3); xs)
        ys .+= xs
    end
end

@assert ys == mapreduce(x -> [x, 2x, 3x], .+, 1:10)
