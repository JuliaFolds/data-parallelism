using FLoops

@floop for x in 1:10
    if isodd(x)
        @reduce(odds = append!(Int[], (x,)))
    else
        @reduce(evens = append!(Int[], (x,)))
    end
end
