# Frequently asked questions

\label{set-nthreads-at-run-time}
## Can I change the number of execution threads without restarting `julia`?

The number of execution threads is specified at the time `julia` is
started (by command line option `-t`/`--threads` or
`JULIA_NUM_THREADS` environment variable).  Thus, to benchmark a
generic Julia program with a different number of threads, you would
need to start a new `julia` process each time.

Some libraries such as Transducers.jl, FLoops.jl, ThreadsX.jl, and
Parallelism.jl support `basesize` option (see, e.g.,
[`Transducers.foldxt`](https://juliafolds.github.io/Transducers.jl/dev/reference/manual/#Transducers.foldxt)).
It is used for specifying the size of the chunk of input collection
processed by one task.  Thus, to simulate running code with `N`
threads, you can pass

```julia
basesize = length(input_collection) ÷ N
```

to run a multi-threaded function (provided that `N ≤
Threads.nthreads()` and there is no other function spawning tasks).
For example:

```julia-repl
julia> sum_nthreads(f, xs, N) = ThreadsX.sum(f, xs; basesize = length(xs) ÷ N);

julia> @btime sum_nthreads(sin, 1:1_000_000, 1);
  16.570 ms (5 allocations: 336 bytes)

julia> @btime sum_nthreads(sin, 1:1_000_000, 2);
  8.318 ms (46 allocations: 2.56 KiB)

julia> @btime sum_nthreads(sin, 1:1_000_000, 4);
  4.403 ms (128 allocations: 7.03 KiB)
```

Note that this trick cannot be used for experimenting with
load-balancing of multi-threaded code since load-balancing requires
starting more than `Threads.nthreads()` tasks.

\label{multi-threading-vs-multi-processing}
## Should I use multi-threading? Or should I use multi-processing?

Julia supports
[threading-based](https://docs.julialang.org/en/v1/manual/multi-threading/)
(via `Base.Threads`) and
[process-based](https://docs.julialang.org/en/v1/manual/distributed-computing/)
(via `Distributed`) parallelism paradigms.  Each paradigm has pros and
cons.  Choosing the best option requires understanding what your
program does.

Ideally, it would be nice if you don't have to make a choice of the
parallelism paradigm before start writing the program.  Frameworks
such as Transducers.jl and FLoops.jl can help you write parallel
algorithm that is agnostic about the execution mechanism
(multi-threading or multi-processing).  However, the multi-processing
backend of these libraries is currently limited compared to
multi-threading backend.

Multi-threading is better for processing complex and large objects
whose serialization become bottleneck in multi-processing -based
parallelism.  Note that
[DistributedArrays.jl](https://github.com/JuliaParallel/DistributedArrays.jl)
can be used to reduce serialization overhead in multi-processing.

If your code allocates many intermediate objects, multi-processing
-based frameworks such as `Distributed` standard library or MPI.jl are
better option.  This is because `julia`'s memory management system can
be a bottleneck for scaling such type of code to many execution
threads.
