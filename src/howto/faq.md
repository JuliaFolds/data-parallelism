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
julia> using ThreadsX, BenchmarkTools

julia> sum_nthreads(f, xs, N) = ThreadsX.sum(f, xs; basesize = length(xs) ÷ N);

julia> @btime sum_nthreads(sin, 1:1_000_000, 1);
  16.570 ms (5 allocations: 336 bytes)

julia> @btime sum_nthreads(sin, 1:1_000_000, 2);
  8.318 ms (46 allocations: 2.56 KiB)

julia> @btime sum_nthreads(sin, 1:1_000_000, 4);
  4.403 ms (128 allocations: 7.03 KiB)
```

Note that this trick cannot be used for experimenting the effect of
the number of threads to the load-balancing of multi-threaded code
since load-balancing requires starting more than `Threads.nthreads()`
tasks.

\label{multi-threading-vs-multi-processing}
## Should I use multi-threading? Or should I use multi-processing?

Julia supports
[threading-based](https://docs.julialang.org/en/v1/manual/multi-threading/)
(via `Base.Threads`) and
[process-based](https://docs.julialang.org/en/v1/manual/distributed-computing/)
(via [Distributed.jl]) parallelism paradigms.  Each paradigm has pros and
cons.  Choosing the best option requires understanding what your
program does.

Multi-threading is better for processing complex and large objects
whose serialization become bottleneck in multi-processing -based
parallelism.  Note that
[DistributedArrays.jl](https://github.com/JuliaParallel/DistributedArrays.jl)
can be used to reduce serialization overhead in multi-processing.

If your code allocates many intermediate objects, multi-processing -based
frameworks such as [Distributed.jl] standard library, [Dagger.jl], or MPI.jl
are better option. This is because `julia`'s memory management system
(garbage collection; GC) can be a bottleneck for scaling such type of code to
many execution threads.

To make it easy to balance with these trade-offs, it is recommended to use a
high-level of abstraction such as data parallelism that helps you switch
underlying execution mechanisms. For example JuliaFolds packages such as
[Folds.jl], [FLoops.jl], and [Transducers.jl] have _executor_ argument to
easily switch thread-based and process-based execution mechanisms.

[Distributed.jl]: https://docs.julialang.org/en/v1/stdlib/Distributed/
[Dagger.jl]: https://github.com/JuliaParallel/Dagger.jl
[Folds.jl]: https://github.com/JuliaFolds/Folds.jl
[FLoops.jl]: https://github.com/JuliaFolds/FLoops.jl
[Transducers.jl]: https://github.com/JuliaFolds/Transducers.jl

## Why is the approach using `state[threadid()]` not mentioned?

See: [What is the difference of `@reduce` and `@init` to the approach using
`state[threadid()]`? · FAQ ·
FLoops](https://juliafolds.github.io/FLoops.jl/dev/explanation/faq/#faq-state-threadid)
