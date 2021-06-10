using FLoops
using OnlineStats

@floop for x in 1:10
    y = 2x
    m = fit!(Mean(), y)
    @reduce() do (acc = Mean(); m)
        merge!(acc, m)
    end
end

@assert acc == fit!(Mean(), 2:2:20)
