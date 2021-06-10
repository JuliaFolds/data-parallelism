# Concurrency patterns for controlled parallelisms

\note{
If you are new to parallel programming in Julia, have a look at other tutorials
such as
[A quick introduction to data parallelism in Julia](../quick-introduction/) and
[Efficient and safe approaches to mutation in data parallelism](../mutations/).
This tutorial is an introduction to how to control the scheduling details of the
parallel execution. But, the best approach is to
[*not*](https://www.infoq.com/presentations/Thinking-Parallel-Programming/)
think about such issues.
}

High-level data parallelism is the best starting point for writing parallel
programs.  However, it is sometimes required to control the parallelism in your
program so that, e.g., the usages of the bounded resources like memory can be
managed. This is where it is necessary to deal with
[_concurrency_](https://blog.golang.org/waza-talk). Although there are a lot
of concurrency primitives, `Channel` is the most versatile tool that Julia
provides out-of-the-box.  In this tutorial, we look at how to implement simple
and useful patterns based on `Channel`.  Some of these patterns are known as
task-parallel [_algorithmic
skeletons_](https://en.wikipedia.org/wiki/Algorithmic_skeleton) (or [_parallel
skeletons_](https://link.springer.com/referenceworkentry/10.1007%2F978-0-387-09766-4_24)).

\tableofcontents

## Worker pool

Useful for:
* Limiting the number of concurrent/parallel tasks.
* Limiting the resource usage.

Pattern:

```julia:workerpool-1
using Base.Threads: @spawn

function workerpool(work!, allocate, request; ntasks = Threads.nthreads())
    @sync for _ in 1:ntasks
        @spawn allocate() do resource
            for input in request
                work!(input, resource)
            end
        end
    end
end
```

```plaintext
﻿                           x7 .----->  work!(x1, resource1)
                             /
request                     /   x9
[..., x12, x11, x10] ------+-------->  work!(x6, resource2)
                            \
                             \
                          x8  `----->  work!(x4, resource3)
```

Note that `request` must define `iterate` that can be invoked from multiple
tasks concurrently. For example, a `Channel` can be used in this pattern.  The
`allocate` function passed as the second argument is used for allocating and
releasing resources.

Following example computes `mean(rand(UInt8, 2^15))` using `/dev/urandom`:

```julia:workerpool-2
# Prepare inputs to the worker pool
results = Vector{Float64}(undef, 2^5)
works = Channel{typeof(Ref(results, 1))}(Inf)
for i in eachindex(results)
    put!(works, Ref(results, i))
end
close(works)

let buffer_length = 2^10

    # `allocate(body)` function allocates the resource and pass it to `body`:
    function allocate(body)
        open("/dev/urandom") do file
            buffer = Vector{UInt8}(undef, buffer_length)
            body((file, buffer))
        end
    end

    # The first argument to `workerpool` is a function that takes a work and a
    # resource:
    workerpool(allocate, works) do ref, (file, buffer)
        read!(file, buffer)
        ref[] = sum(buffer; init = 0.0)
    end

    sum(results) / (length(results) * buffer_length)
end
```

\show{workerpool-2}

### Re-distribution hacks

As of version 1.6, Julia's parallel task runtime does not migrate tasks across
worker threads once a task is started. Thus, depending on when the worker pool
is constructed, the above code many not distribute the tasks across worker
threads. If there is no need to allocate the resource for each worker, the best
solution is to use [`Threads.foreach(_,
::Channel)`](https://docs.julialang.org/en/v1/base/multi-threading/#Base.Threads.foreach).
added in Julia 1.6, if you don't need to run `resource = allocate()` as above.

If you need to allocate the resource, a simple workaround to this problem is to
spawn a new task for each call to `work!`. This is the strategy used in
`Threads.foreach`.

```julia:workerpool_redist
function workerpool_redist(work!, allocate, request; kwargs...)
    workerpool(allocate, request; kwargs...) do input, resource
        wait(@spawn work!(input, resource))
    end
end
```

Another (less recommended) approach is to let `@threads` distribute the tasks

```julia
@sync @threads for _ in 1:ntasks
    allocate() do resource
        @async for input in request
            work!(input, resource)
        end
    end
end
```

This approach is not recommended because (1) how `@threads for` schedules the
tasks is an implementation detail and (2) use of `@async` impedes migration of
the tasks across OS threads (which is not implemented as of Julia 1.6 but is
likely to be implemented in the future Julia versions).

## Task farm

Useful for:
* Limiting resources like worker pool.
* Passing outputs into downstream processing.
* Chaining computations with different resource requirements.

Pattern:

```julia
ys = Channel() do ys
    @sync for _ in 1:ntasks
        @spawn for x in xs
            put!(ys, f(x))
        end
    end
end
```

```plaintext
﻿                           x7 .------ f -------.  f(x4)
                             /                  \
                            /  x9         f(x6)  \
[..., x12, x11, x10] ------+--------- f ----------+----------> [f(x1), f(x5), f(x2), ...]
                            \                    /
                             \                  /
                          x8  `------ f -------`  f(x3)
```

This is an extension of the worker pool pattern. It is useful for limiting the
number of concurrent/parallel tasks. However, as the diagram above indicates, it
does not preserve the ordering of input (hence `u` in `umap` for unordered):

```julia:umap-1
umap(f, xs; kwargs...) = umap(f, Any, xs; kwargs...)
function umap(f, TY::Type, xs::Channel; ntasks = Threads.nthreads(), buffersize = ntasks)
    return Channel{TY}(buffersize) do ys
        @sync for _ in 1:ntasks
            @spawn for x in xs
                put!(ys, f(x))
            end
        end
    end
end
```

Note that the input collection `xs` must support concurrent iteration.  To
support arbitrary input collection, we can automatically wrap it in a fallback
implementation:

```julia:umap-2
function umap(f, TY::Type, xs; kwargs...)
    @assert !(xs isa Channel)  # hide
    ch = Channel{eltype(xs)}() do ch
        for x in xs
            put!(ch, x)
        end
    end
    return umap(f, TY, ch; kwargs...)
end
```

This pattern is called the _task farm_ algorithmic skeleton.

`umap` can be used like `Iterators.map` although the ordering is not preserved:

```julia:umap-3
function slow_square(x)
    sleep(rand(0.01:0.01:0.3))
    return x^2
end

ans = begin # hide
collect(umap(slow_square, 1:10; ntasks = 5))
end # hide
@assert sort(ans) == (1:10) .^ 2 # hide
ans # hide
```

\show{umap-3}

## Pipeline

An interesting use-case is to call `umap` with `ntasks = 1` but with a long
chain of calls:

```julia
a = umap(f, xs; ntasks = 1)
b = umap(g, a; ntasks = 1)
c = umap(h, b; ntasks = 1)
```

```plaintext
step    items in a     items in b     items in c
------- -------------- -------------- ------------
  1     a1 = f(x1)
  2     a2 = f(x2);    b1 = g(a1)
  3     a3 = f(x3);    b2 = g(a2);    c1 = h(b1)
  4     a4 = f(x4);    b3 = g(a3);    c2 = h(b2)
  5     a5 = f(x5);    b4 = g(a4);    c3 = h(b3)
  6     a6 = f(x5);    b5 = g(a4);    c4 = h(b4)
  7     a7 = f(x7);    b6 = g(a4);    c5 = h(b5)
  8     a8 = f(x7);    b7 = g(a5);    c6 = h(b6)
  9                    b8 = g(a8);    c7 = h(b7)
 10                                   c8 = h(b7)
```

If `ntask = 1`, the ordering of the input is preserved in the output. It can
be used to improve the performance as long as `buffersize > 0` and the length
of the input is long enough. In this case, different functions (`f`, `g`, and
`h` in the above example) can be evaluated in parallel. This pattern is called
the _pipeline_ algorithmic skeleton.

## Promise (request-response)

Useful for:
* Limiting resources like worker pool.
* Associating input and output.

The task farm pattern has an unfortunate restriction that it does not preserve
the ordering of input. Can we make it work when we want to relate the input and
output?  One approach is to combine [promise (or
future)](https://en.wikipedia.org/wiki/Futures_and_promises) with the worker
pool pattern.

Similar to the worker pool pattern, we still use a channel as the request queue
(`request`) that the worker waits for the works. The key trick here is to send
another channel (`promise`) over the request channel together with the input
describing the work.  Once the worker finish the computation, it "returns" the
result by putting it in the `promise` channel.

```julia:raw_service
function raw_service(f; ntasks = Threads.nthreads())
    request = Channel() do request
        @sync for _ in 1:ntasks
            @spawn for (x, promise) in request
                y = f(x)
                put!(promise, y)
            end
        end
    end
    return request
end

function call(request, x)
    promise = Channel(1)
    put!(request, (x, promise))
    return take!(promise)
end

adder = raw_service() do x
    return x + 1
end
try
    @assert call(adder, 0) == 1
    @assert call(adder, 1) == 2
finally
    close(adder)
end
```

Several variants are possible:

* If the input and the output type of `f` is known (say `X` and `Y`) we can use
  `Channel{Y}` as the `promise` channel and `Channel{Tuple{X,Channel{Y}}}` as
  the `request` channel.
* If `f` needs some resources, it can be allocated once per worker.

Another useful variant may be an asynchronous call API:

```julia
function async_call(request, x)
    promise = Channel(1)
    put!(request, (x, promise))
    return promise  # no take!
end
```

The caller can schedule the call and then retrieve the result (using `take!`) at
different locations in the code.  It is also useful for scheduling multiple
concurrent (and potentially parallel) calls.  

### Improving the API

The above API using `raw_service` and `call` has a problem that the user must
close the channel `adder` to cleanup the resources (tasks) deterministically and
handle errors reliably.  It's better to wrap our API so that it can be used with
the `do` block pattern (c.f., `open(f, path)`) instead of explicit
`try`-`finally`:

```julia:define_service
function provide(body, request)
    endpoint(x) = call(request, x)
    try
        body(endpoint)
    finally
        close(request)
    end
end

function define_service(f; kwargs...)
    open_service(body) = provide(body, raw_service(f; kwargs...))
    return open_service
end
```

We can use this API in two steps: (1) define the serve and then (2) "open" it
using another `do` block:

```julia:with_adder
with_adder = define_service() do x
    return x + 1
end
with_adder() do add
    @assert add(0) == 1
    @assert add(1) == 2
end
```

### Wrapping single-thread API

This pattern is useful also as an ad-hoc interface around an API that is not
safe to call from arbitrary OS threads:

```julia:define_single_thread_service
function define_single_thread_service(f)
    function open_service(body)
        request = Channel() do request
            for (x, promise) in request
                y = f(x)
                put!(promise, y)
            end
        end
        provide(body, request)
    end
    return open_service
end

with_adder = define_single_thread_service() do x
    return x + 1  # call a "thread-unsafe" API here
end
with_adder() do add
    @assert add(0) == 1
    @assert add(1) == 2
end
```

This function makes sure (as of Julia 1.6) that `f` is called on the OS thread
that `with_adder(body)` is called while `add(x)` can be called in any tasks.

Note that the call to the "thread-unsafe" function `f` becomes the bottleneck if
you use  `define_single_thread_service(f)` because every worker has to wait for
the preceding calls of `f`. It may be a reasonable approach when the execution
time of `f` is much smaller than the parallelized portion of your program.
However, if it is not the case, it may be better to switch to process-based
parallelism (using Distributed.jl, Dagger.jl, etc.) instead of threading-based
parallelism.

## See also

* [JuliaActors/Actors.jl](https://github.com/JuliaActors/Actors.jl)
  (Concurrent computing in Julia based on the Actor Model)
  and other packages in <https://github.com/JuliaActors/>
