# A demo for false sharing and its analysis using `perf c2c`.
#
# This script runs two Julia functions that does equivalent computations with
# different memory layouts. The performance counters are analyzed using `perf
# c2c` and the result files are dumped into the current working directory.
#
# This script works probably only on Intel CPU.

if !success(`perf c2c record -- --output=/dev/null true`)
    error("`perf c2c` not supported")
end

using BenchmarkTools

function perf_c2c_record(f, output)
    # Compile `f` and also (hopefully) let CPUs converge to a stationary state.
    f()

    proc = run(
        pipeline(`perf c2c record -- --output=$output`; stdout = stdout, stderr = stderr);
        wait = false,
    )
    try
        f()
    finally
        flush(stdout)
        flush(stderr)
        kill(proc, Base.SIGINT)
        wait(proc)
    end
end

function perf_c2c_report(input, output)
    # `-c tid,iaddr` for showing the Tid column
    cmd = `perf c2c report --input=$input -c tid,iaddr`
    @info "$cmd > $output"
    open(output; write = true) do io
        run(pipeline(cmd; stdout = io))
    end
end

# SYS_gettid == 186 from /usr/include/x86_64-linux-gnu/asm/unistd_64.h
gettid() = @ccall syscall(186::Clong;)::Clong
@assert gettid() == getpid()

function worker_tids()
    tids = zeros(Int, Threads.nthreads())
    Threads.@threads :static for _ in 1:Threads.nthreads()
        tids[Threads.threadid()] = gettid()
    end
    return tids
end

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


@noinline bench_crowded_inc() = @btime crowded_inc!(ys, data)
@noinline bench_exclusive_inc() = @btime exclusive_inc!(yss, data)


@info "Benchmarking `crowded_inc!`"
perf_c2c_record(bench_crowded_inc, "crowded_inc-perf.data")

@info "Benchmarking `exclusive_inc!`"
perf_c2c_record(bench_exclusive_inc, "exclusive_inc-perf.data")


open("pointers.txt"; write = true) do io
    function ln(label, ptr::Ptr)
        print(io, label, ",\t")
        show(io, UInt(ptr))
        println(io)
    end
    ln("ys[1]", pointer(ys, 1))
    ln("ys[end]", pointer(ys, length(ys)))
    for (i, ys) in pairs(yss)
        ln("yss[$i][1]", pointer(ys, 1))
        ln("yss[$i][end]", pointer(ys, length(ys)))
    end
end

open("worker_tids.txt"; write = true) do io
    for tid in worker_tids()
        println(io, tid)
    end
end

perf_c2c_report("crowded_inc-perf.data", "crowded_inc-perf.txt")
perf_c2c_report("exclusive_inc-perf.data", "exclusive_inc-perf.txt")
