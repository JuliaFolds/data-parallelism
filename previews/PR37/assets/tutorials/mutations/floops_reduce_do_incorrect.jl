@floop for n in 1:10
    xs = [n, 2n, 3n]
    @reduce() do (ys = zeros(Int, 3); xs)
        ys .+= 2 .* xs  # INCORRECT
    end
end
