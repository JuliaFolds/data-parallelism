@floop for n in 1:10
    xs = [n, 2n, 3n]
    @reduce() do (ys = zeros(Int, 3); xs)
#                 ~~~~~~~~~~~~~~~~~~
#                  initializer
        ys .+= xs
#       ~~~~~~~~~
#       reduce body
    end
end

@assert ys == mapreduce(n -> [n, 2n, 3n], .+, 1:10)
