function basecase(chunk)
    odds = Int[]  # init
    evens = Int[]  # init
    for x in chunk
        if isodd(x)
            odds = append!(odds, (x,))
        else
            evens = append!(evens, (x,))
        end
    end
    return (odds, evens)
end
