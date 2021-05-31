using BenchmarkTools

function crowded_inc!(ys, data)
    Threads.@threads :static for indices in data
        for i in indices
            @inbounds ys[i] += 1
        end
    end
end

function exclusive_inc!(yss, data)
    Threads.@threads :static for indices in data
        ys = yss[Threads.threadid()]
        for i in indices
            @inbounds ys[i] += 1
        end
    end
end

cacheline = try
    parse(Int, read("/sys/devices/system/cpu/cpu0/cache/index0/coherency_line_size", String))
catch err
    @warn "cannot read cache line size" exception = (err, catch_backtrace())
    64
end

ys = zeros(Threads.nthreads() * 2);
partitioned_indices = reshape(eachindex(ys), Threads.nthreads(), :)'
data = [rand(partitioned_indices[:, i], 2^20) for i in 1:Threads.nthreads()]
yss = [zeros(length(ys) + cld(cacheline, sizeof(eltype(ys)))) for _ in 1:Threads.nthreads()];


trial_crowded_inc = @benchmark crowded_inc!(ys, data) setup = fill!(ys, 0)
display(trial_crowded_inc)
trial_exclusive_inc =
    @benchmark exclusive_inc!(yss, data) setup = foreach(ys -> fill(ys, 0), yss)
display(trial_exclusive_inc)
