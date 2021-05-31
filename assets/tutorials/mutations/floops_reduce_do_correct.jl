@floop for n in 1:10
    xs = [n, 2n, 3n]
    zs = 2 .* xs  # CORRECT
    @reduce() do (ys = zeros(Int, 3); zs)
        ys .+= zs
    end
end

@assert ys == mapreduce(n -> 2 .* [n, 2n, 3n], .+, 1:10)
