function basecase(chunk)
    ys = zeros(Int, 3)         # initializer
    for n in chunk
        xs = [n, 2n, 3n]
        ys .+= xs              # reduce body
    end
    return ys
end
