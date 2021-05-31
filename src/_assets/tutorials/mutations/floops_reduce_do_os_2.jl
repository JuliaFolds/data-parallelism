@floop for x in 1:10
    y = 2x
    @reduce() do (acc = Mean(); y)
        if y isa OnlineStat
            merge!(acc, y)
        else
            fit!(acc, y)
        end
    end
end

@assert acc == fit!(Mean(), 2:2:20)
