using FLoops

@floop for x in 1:10
    if isodd(x)
        @reduce(odds = vcat(Int[], [x]))
    else
        @reduce(evens = vcat(Int[], [x]))
    end
end
