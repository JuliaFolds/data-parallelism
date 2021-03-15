# Efficient and safe approaches to mutation in data parallelism

As discussed in [a quick introduction to data
parallelism](../quick-introduction), data parallel style lets us write fast,
portable, and generic parallel programs. One of the main focuses was to
unlearn the "sequential idiom" that accumulates the result into mutable
state. However, mutable state is sometimes preferred for efficiency. After all,
a fast parallel program is typically a composition of fast sequential programs.
Furthermore, managing mutable states is sometimes unavoidable for
interoperability with libraries preferring or requiring mutation-based API.
However, sharing mutable state is almost always a bad idea.  Naively doing so
likely results in [data races](https://en.wikipedia.org/wiki/Data_race) and
hence programs with [undefined
behaviors](https://en.wikipedia.org/wiki/Undefined_behavior).  Although
low-level concurrency APIs such as locks and atomics can be used for writing
(typically) *inefficient* but technically correct programs, a better approach is
to use single-owner local mutable state [^concurrency].  In particular, we will
see that unlearning sequential idiom was worth the effort since it points
us to what we call [ownership-passing style](#ownership-passing-style) that can
be used to construct mutation-based parallel reduction from mutation-free
("purely functional") reduction *as an optimization*.  This tutorial provides an
overview of the mutable object handling in data-parallel Julia programs
[^threadid].  It also discusses the effect and analysis of [false
sharing](https://en.wikipedia.org/wiki/False_sharing) which is a major
performance pitfall when using in-place operations in a parallel program.

[^concurrency]: Locks and atomics are important building blocks for concurrent programming and [non-blocking algorithms and data structures](https://en.wikipedia.org/wiki/Non-blocking_algorithm) are very useful for high-performance applications. Although these aspects become non-negligible for squeezing out the "last bits" of the performance, we here focus on how to construct parallel programs independent of how the synchronizations and scheduling are managed. This is the key for writing portable and correct parallel programs. See also: [concurrency is not parallelism](https://blog.golang.org/waza-talk).

[^threadid]: If you are familiar with the approach using `threadid` and wonder why it is not discussed here, take a look at [What is the difference of `@reduce` and `@init` to the approach using `state[threadid()]`? · FAQ · FLoops](https://juliafolds.github.io/FLoops.jl/dev/explanation/faq/#faq-state-threadid).

<!-- footnote parsing does not handle newlines? -->

\tableofcontents

\label{sum-mul-zip}
## Example: multiplying and adding matrices

\note{
This section can be skipped.  It is a quick tour on "practical" Julia code that
uses parallel loop and manipulates mutable objects.  It does not explain all the
concepts in order.  The explanations in the [next sections](#categorization)
take more bottom-up approach.
}

As a starting point, let us consider the following program that computes a sum
of products of matrices: [^einsum]

\input{julia}{/assets/tutorials/mutations/example_1.jl}

[^einsum]: If you can store the inputs as `AbstractArray{T,3}`s, it may be better to use higher-level data parallel libraries such as [Tullio.jl](https://github.com/mcabbott/Tullio.jl) and [TensorOperations.jl](https://github.com/Jutho/TensorOperations.jl).

As explained in the [quick introduction](../quick-introduction), this program
can easily be translated to a parallel program, e.g., by using Folds.jl:

\input{julia}{/assets/tutorials/mutations/example_2.jl}

This program is suboptimal since it allocates temporary arrays for the
multiplications and summations.  To clarify the source of allocations, let us
translate the above code using `@floop` (see [`FLoops.@reduce`](#floops-reduce)
below for how it works):

\input{julia}{/assets/tutorials/mutations/example_3.jl}

We can eliminate the allocation of `A * B` by using `LinearAlgebra.mul!` and
the allocation of `S + C` by using the inplace broadcasting updates `S .+=
C`. However, we cannot allocate arrays `C` and `S` outside `@floop` because
then they will be shared across multiple tasks (and causes data races).
Fortunately, we can use `@init` macro for allocating "private" temporary
array `C` and the "init clause" of `@reduce` macro (i.e., `zero(C)` in the
code below):

\input{julia}{/assets/tutorials/mutations/example_4.jl}

In above code, `similar(A)` and `zero(C)` are executed only once in each task
and their results are re-used. The result `S₁` from task 1 and result `S₂` from
task 2 are combined using the reduction specified by `@reduce()`; i.e., `S₁ .+=
S₂`.

\label{fused-mul}
### Advanced: fusing multiplication and addition in base cases

The previous program provides a decent performance for a straightforward
piece of code. However, we can further optimize the program by using fused
multiply-add provided by the 5-argument method `mul!(C, A, B, α, β)`. We can
use this method for the base cases (where we have matrices `A` and `B`) but
we need to use `.+=` when combining the base cases. This can be done by
dispatching on the type of the second argument of `@reduce`:

\input{julia}{/assets/tutorials/mutations/example_5.jl}

\label{categorization}
## Categorizing mutation use-cases

Let's discuss different kinds of mutability in parallel programs separately:

1. Filling outputs
2. In-place reductions
3. Mutable temporary objects (private variables)

## Filling outputs

Perhaps the simplest use of mutation in parallel program is filling
pre-allocated output.

\input{julia}{/assets/tutorials/mutations/filling_1.jl}

This loop can also be written as `Threads.@threads`:

\input{julia}{/assets/tutorials/mutations/filling_2.jl}

A more succinct approach is `Folds.map!`:

\input{julia}{/assets/tutorials/mutations/filling_3.jl}

\label{filling-output-pitfalls}
### Pitfalls with filling pre-allocated outputs

This type of parallel mutation relies on that different tasks mutate disjoint
set of memory locations. The correctness of the above code examples rely on that
`ys` is, e.g., an `Array`. That is to say, updating each element `ys[i]` only
updates data at disjoint memory location for different index `i` and does not
depend on the memory locations updated by other tasks.  However, it is not the
case for more complex data collections such as

*  Certain `view`s such as `ys = view([0], [1, 1, 1, 1])`. Mutating `ys[1]`
   mutates `ys[2]`, `ys[3]`, and `ys[4]`.
* `BitArray`: `ys[i]` and `ys[i+1]` may be stored in a single `UInt64`.
* `SparseMatrixCSC`, `SparseVector`: Assigning a value to a previously zero index
   requires moving data for other non-zero elements internally.
* `Dict`: inserting a new key-vale pair mutates memory locations shared by other
  tasks.

These are all examples of [data
races](https://en.wikipedia.org/wiki/Race_condition): there are multiple
unsynchronized concurrent accesses and at least one of the accesses is write.

On the other hand, non-`Array` types can also be used safely.  For example, `ys
= view(::Vector, 1:50)` can be used instead of a `Vector` since `ys[i]` and
`ys[j]` (`i ≠ j`) refer to disjoint memory locations.

## In-place reductions

Many sequential programs compute the result by mutating some states; e.g.,
appending elements to a vector. This approach is very efficient and is useful as
a base case of parallel programs. There are several approaches to safely use
such sequential reductions in parallel programs.

\label{floops-reduce}
### Flexible reduction with `FLoops.@reduce`

#### `@reduce(acc = op(init, input))` example

FLoops.jl is a package for a flexible set of syntax sugar for [constructing
parallel loops](https://juliafolds.github.io/FLoops.jl/dev/tutorials/parallel/).
In particular, we can use `@reduce(acc = op(init, input))` syntax for writing
parallel reduction:

\input{julia}{/assets/tutorials/mutations/floops_reduce_1.jl}

Here, we use `@reduce` with the following syntax

```julia
# @reduce($acc = $op(    $init, $input))
  @reduce(odds = append!(Int[], (x,)))
#         ~~~~   ~~~~~~~ ~~~~~  ~~~~
#          |       |      |      |
#          |       |      |     Input to reduction
#          |       |      |
#          |       |   Initialization of the accumulator
#          |       |
#          |      Reducing function (aka binary operator, monoid)
#          |
#   Accumulator (result of the reduction)
```

The `@reduce` macro is used for generating two types of code (function).  First,
it is used for generating the base case code. The base case code is generated by
(roughly speaking):

1. remove `@reduce(` and the corresponding `)`
2. replace `$init` in the first argument with `$acc`
3. put `$acc = $init` in front of the loop

i.e.,

\input{julia}{/assets/tutorials/mutations/floops_reduce_2.jl}

Input collection to `@floop for` loop is split into chunks first[^dac].  For
example, if `julia` is started with `--threads=2`, it is split into two chunks
by default:

\input{julia}{/assets/tutorials/mutations/floops_reduce_3.jl}

Each chunk is then processed by (a function equivalent to) the `basecase`
function above:

\input{julia}{/assets/tutorials/mutations/floops_reduce_4.jl}

The function `append!` specified by `@reduce` is used also for merging these
base case results:

\input{julia}{/assets/tutorials/mutations/floops_reduce_5.jl}

When there are more than two chunks, the reduction results are merged pair-wise
(default [^dac]) or sequentially, depending on the
[executor](https://juliafolds.github.io/Transducers.jl/dev/explanation/glossary/#glossary-executor)
used.

[^dac]: By default, JuliaFolds packages use divide-and-conquer approach for scheduling parallel loops. Roughly speaking, it "fuses" splitting of the collections and scheduling the parallel tasks. It also "fuses" the merges of reduction results and joining of the parallel tasks. This increases [parallelism](https://www.cprogramming.com/parallelism.html) of the entire computation compared to more naive sequential scheduling.  However, FLoops.jl itself is just a syntax sugar for defining parallel reduction and completely decoupled from _how_ these reductions are computed. The exact execution strategy can be determined by passing the [executor](https://juliafolds.github.io/Transducers.jl/dev/explanation/glossary/#glossary-executor).

\label{ownership-passing-style}
#### Ownership-passing style

Note that the above parallel reduction does not incur data races because

1. The first arguments to `append!` are created for each base case,
2. `append!` mutates the first argument and returns it, and
3. `append!` is used in such a way that the first argument (more specifically
   its state at which `append!` is called) is never used.

Therefore, we can treat `append!` *as if* it were a pure function for the
purpose of understanding this parallel reduction. In other words, we never
observe the side-effect of `append!` through the argument. It's easy to see
that the above program is correct even if we replace `append!` with its
mutation-free "equivalent" [^vcattuple] function `vcat`:

[^vcattuple]: Note that the equivalence is not quite exact. We replace `(x,)` with `[x]` since `append!` and `vcat` behave differently when the input is non an array.

\input{julia}{/assets/tutorials/mutations/floops_reduce_6_vcat.jl}

This observation points to a powerful recipe for constructing efficient parallel
reduction:

1. Write down parallel reduction without using mutation.
2. Re-write the reducing function (the body of `@reduce` or the binary function
   `op` passed to `reduce` etc.; i.e., monoid) by mutating the first argument.
3. Make sure that subsequent iterations do not mutate the second argument (See
   the discussion [below](#ownership-passing-style-second-argument))

It can be used for general reducing functions (`op`) specified via `@reduce`
macro as well as the functions passed to higher-order functions such as `reduce`
in all JuliaFolds packages.  Furthermore, this style allows us to replace
`append!` with
[`BangBang.append!!`](https://juliafolds.github.io/BangBang.jl/stable/#BangBang.append!!)
which is very useful for collecting elements when their type cannot be
determined or hard to do so *a priori*. For lack of better words, let us call it
*ownership-passing style* (a non-standard terminology). This is because the
ownership of `dest` in `dest′ = append!(dest, src)` is first transferred to
`append!` which then it is transferred back to the caller as the return value
`dest′`.

Note that there is a subtlety when it comes to the ownership of the second
argument. See the discussion [below](#ownership-passing-style-second-argument).

#### `@reduce() do` example

`@reduce() do` syntax can be used for defining a more flexible reduction (see
also the [example section](#sum-mul-zip) above). Here is a simple example

\input{julia}{/assets/tutorials/mutations/floops_reduce_do_1.jl}

The base case code is equivalent to the loop transformed by:

1. remove `@reduce() do ($acc₁ = $init₁; $input₁), …, ($accₙ = $initₙ; $inputₙ)`
   and the corresponding `end` and keep the reduce body
3. put the initializers `$accᵢ = $initᵢ` in front of the loop

i.e.,

\input{julia}{/assets/tutorials/mutations/floops_reduce_do_2.jl}

Similar to `odds`-`evens` example above, the input collection is chunked and
then processed in multiple tasks:

\input{julia}{/assets/tutorials/mutations/floops_reduce_do_3.jl}

Finally, the base case results are merged by using the body of the `@reduce()
do` block (here, just `.+=`):

\input{julia}{/assets/tutorials/mutations/floops_reduce_do_4.jl}

#### General form of `@reduce() do` syntax

In general, `@reduce() do` takes the following form:

```julia
@reduce() do ($acc₁ = $init₁; $input₁),
             ($acc₂ = $init₂; $input₂),
              …
             ($accₙ = $initₙ; $inputₙ)
#              ~~~~    ~~~~~   ~~~~~~
#               |       |        |
#               |       |      Input to reduction (computed outside `@reduce`)
#               |       |
#               |   Initialization of the accumulator
#               |
#             Accumulator (result of the reduction)
    $body
#   ~~~~~
#   Reducing function (aka binary operator, monoid)
end
```

This expression is used to generate the following function `op` for merging two
set of `accᵢ`s from two tasks

```julia
function op(accs_left, accs_right)
    ($acc₁, $acc₂, …, $accₙ) = accs_left
    ($input₁, $input₂, …, $inputₙ) = accs_right
    $body
    return ($acc₁, $acc₂, …, $accₙ)
end
```

which is invoked as

```
accs = op(accs_left, accs_right)
```

to merge the results of "left" and "right" tasks.  When using `@reduce($acc =
$op($init, $input))` syntax, the function `$op` is used as-is.

Note that the roles of `$accᵢ`s and `$inputᵢ`s are almost "symmetric" in the
sense that `$body` has to be able to handle any value of `$accᵢ` provided as a
`$inputᵢ`.

The reducing function must be associative; i.e., the results of

```julia
op(op(a, b), c)
```

and

```julia
op(a, op(b, c))
```

must be equivalent in some sense (e.g., `isapprox` may be enough in some cases;
the result of `@floop` is still deterministic unless a nondeterministic
executor is specified or the input collection is unordered).

Furthermore, since the function `op` has to be executable outside the scope of
the sequential loop, it must not use variables whose scope is inside of `@floop`
but outside of `@reduce`.  That is to say, it must only access variables
`$accᵢ`s and `$inputᵢ`s or the names defined outside `@floop`:

```julia
using SomeModule: f

function example()
    ...
    x = ...
    @floop for ...
        y = ...
        z = ...
        @reduce() do (acc; y)
            acc   ✅ # accessible (accumulator)
            f     ✅ # accessible (global)
            x     ✅ # accessible (defined outside @floop)
            y     ✅ # accessible (passed as an input)
            z     ❌ # NOT accessible (not passed as an input)
            ...
        end
    end
    ...
end
```

These requirements for associativity and variable scoping typically can be
achieved by "minimizing" the computation done inside `@reduce`.  The following
example is incorrect since the body of `@reduce` is doing an "extra work":

\input{julia}{/assets/tutorials/mutations/floops_reduce_do_incorrect.jl}

A correct implementation is to move the computation `2 .* xs` out of `@reduce`.

\input{julia}{/assets/tutorials/mutations/floops_reduce_do_correct.jl}

The allocation of temporary variables such as `zs` can be eliminated by using
[private variables (see below)](#private-variables).  It is also possible to
fuse the computation of `2 .* _` and `_ .+= _` if done carefully (See the
example above for [how to fuse computation only in the base case](#fused-mul)).

\label{ownership-passing-style-second-argument}
#### Ownership-passing style: second argument

Consider the following program that computes sum of arrays

\input{julia}{/assets/tutorials/mutations/ownership_passing_style_second_1_intro.jl}

Since the element type of the input is unknown, we can't pre-compute the output
array type. It may then be tempting to use the first input as the accumulator:

\input{julia}{/assets/tutorials/mutations/ownership_passing_style_second_2_wrong.jl}

However, as you can see in the `@assert` statement above, this loop mutated the
first element `vectors[1]`. This is probably not a desirable outcome in many
cases (although it may not be problem in specific use cases). Thus, in general,
we should assume that *the reducing function does not own second argument* when
using the ownership-passing style. Therefore, we need to *copy* the second
argument when using it as the accumulator.

\input{julia}{/assets/tutorials/mutations/ownership_passing_style_second_3_correct.jl}

### Initializing mutable accumulator using `Transducers.OnInit`

[`Transducers.OnInit(f)`](https://juliafolds.github.io/Transducers.jl/dev/reference/manual/#Transducers.OnInit)
can be passed as `init` argument in many JuliaFolds API.  It calls the
zero-argument function `f` that creates the accumulator for each base case:

\input{julia}{/assets/tutorials/mutations/transducers_oninit.jl}

### Combining containers

When each iteration produce a container, there is usually a "default" way to
combine all the containers produced. For basic containers such as vectors, sets
and dictionaries, `Base` already define appropriate functions:

| Container  | Pure function   | In-place function |
| ---------- | --------------- | ----------------- |
| vector     | `vcat`          | `append!`         |
| set        | `union`         | `union!`          |
| dictionary | `merge`         | `merge!`          |
|            | `mergewith(op)` | `mergewith!(op)`  |

(These are not the only associative operations on these containers.  For
example, `union` works on vectors, too.  `intersect` defines another associative
operations on sets.)

The corresponding containers can be constructed in parallel by feeding
sub-containers into these "merging" functions:

\input{julia}{/assets/tutorials/mutations/combining_containers_1.jl}

However, it is suboptimal to heap-allocate these singleton containers
(containers with single element). We can use special singleton containers from
MicroCollections.jl to avoid heap allocations. Another downside of the approach
using functions such as `append!` is that they require specifying element type
before the reduction is started. This is sometimes impossible or very tedious.
We can avoid it by using the `!!` functions from BangBang.jl.  For example,
`BangBang.append!!(ys, xs)` may return a new array without mutating `ys` if the
element type of `ys` is not appropriate for storing `xs`.  Thus, in the parallel
reduction context, BangBang.jl functions can be used more like pure functions
except that the objects passed as the first argument cannot be re-used again.

\input{julia}{/assets/tutorials/mutations/combining_containers_2.jl}

Since these are common idioms, Folds.jl has shorthands for the first three cases:

\input{julia}{/assets/tutorials/mutations/combining_containers_3.jl}

### `OnlineStats`

[OnlineStats.jl](https://github.com/joshday/OnlineStats.jl) is a rich collection
of composable single-pass algorithms for computing various statistics.  Although
OnlineStats.jl itself only provides in-place operations, Transducers.jl defines
a compatibility layer (using `OnInit` etc.) that treat mergeable `OnlineStat`s
as monoids.  `Folds.reduce` probably is the easiest API to use:

```julia:folds-onlinestats
using OnlineStats
using Folds
ans = begin # hide
Folds.reduce(Mean(), 1:10)
end # hide
@assert ans == fit!(Mean(), 1:10)  # hide
ans # hide
```

\show{folds-onlinestats}

We can also use `FLoops.@reduce` directly with OnlineStats.jl. The key point is
to make the body of `@reduce` "symmetric in type"; i.e., pass `Mean` at both
arguments:

\input{julia}{/assets/tutorials/mutations/floops_reduce_do_os_1.jl}

It is also possible to get rid of the intermediate `Mean` object by "fusing"
`fit!` and `merge!` in the base case.  (However, this optimization may not be
required since the compiler is likely to optimize away the creation of
intermediate `Mean` object `m`.)

\input{julia}{/assets/tutorials/mutations/floops_reduce_do_os_2.jl}

\label{reduce-pitfalls}
### Pitfalls with mutable reduction states

When using in-place reductions, mutable accumulators must be specified carefully
to avoid sharing them across tasks. For example,

```julia
Folds.mapreduce(x -> (x,), append!, xs; init = [])
```

is not a correct parallel program since it mutates the array `[]` in multiple
tasks.  The APIs such as `FLoops.@reduce` discussed above can be used to avoid
this problem when used correctly. However, it's still possible to misuse the
API.  For example,

```julia
using FLoops

shared_acc = []  # WRONG (shared across tasks and mutated concurrently)
@floop for x in 1:10
    ys = (x,)
    @reduce(acc = append!(shared_acc, ys))
end
```

has exactly the same problem as `init = []`.

\label{private-variables}
## Mutable temporary objects (private variables)

In addition to pre-allocated objects or mutable accumulators, it is sometimes
necessary to have mutable temporary objects.  While temporary objects are
technically equivalent to accumulators that are ignored after the loop, it is
convenient to have a dedicated API. This is why FLoops.jl has `@init` macro that
declares "private variables" for re-using mutable temporary objects within each
base case:

\input{julia}{/assets/tutorials/mutations/floops_init_1.jl}

The right hand sides of the assignments in `@init` is executed only at the first
iteration of each base case.

## Accidental mutations

Many parallel APIs in Julia, including `@threads` and `@spawn`, require creating
closures. Thus, it is a common mistake to accidentally expand the scope of local
variables. For example, the scope of `y` in the following program is larger than
`@threads for` loop. As a result, the update of `y` is shared across all tasks
and this function has a data race:

\input{julia}{/assets/tutorials/mutations/accidental_mutations_1_threads.jl}

The data race is observable if there is a non-inlinable function call
(`some_function()` in the example) between the definition and the use of `y`.
If we run the above function multiple times in a `julia` process started with
multiple worker threads, we can observe that the result is different from the
expected value:

\input{julia}{/assets/tutorials/mutations/accidental_mutations_2_seq.jl}


```julia-repl
julia> ys = f_seq()
       for i in 1:100
           @assert f() == ys
       end
ERROR: AssertionError: f() == ys
```

We can use the `local` keyword to fix it:

```julia
Threads.@threads for i in 1:n
    local y = gcd(42, i)  # added `local`
    some_function()
    ys[i] = y
end
```

Alternatively, if the loop body of `Threads.@threads` or the thunk of
`Threads.@spawn` is large, it is a good idea to factor it out as a function.  It
prevents assignments inside the closure and hence the data races.  It also makes
analyzing base case performance easier.

Using FLoops.jl instead of `@threads` is useful to prevent this bug.  Consider
an equivalent parallel loop written with FLoops.jl:

\input{julia}{/assets/tutorials/mutations/accidental_mutations_4_floop.jl}

FLoops.jl detects that the variable `y` is now shared across all tasks:

```julia-repl
julia> f_floop()
ERROR: HasBoxedVariableError: Closure __##reducing_function#258 (defined in Main) has 1 boxed variable: y
HINT: Consider adding declarations such as `local y` at the narrowest possible scope required.
```

As the error message indicates, `local y = gcd(42, i)` also fix the issue in
`@floop`.

\label{false-sharing}
## Advanced/Performance: False sharing

Even when parallel programs are correctly written to handle mutable objects, it
may not perform well due to [_false
sharing_](https://en.wikipedia.org/wiki/False_sharing). False sharing can occur
when the code running on different CPUs update adjacent (but disjoint) memory
locations. The program is still data race-free (not "true" sharing) since it
does not simultaneously mutate the same memory locations.  However, since the
CPU manages the data in a unit (cache line) larger than single bytes, the CPUs
have to communicate each other to maintain the coherent view of the data and
avoid such simultaneous modification of the "same" memory location (from the
point of view of the CPUs). This extra communication slows down the program.

\note{
False sharing is hard to invoke when using the patterns discussed above due to
Julia's memory management.  On the other hand, the use of `state[threadid()]`
pattern to create "thread-local storage" for reduction or private variables is
more likely to invoke false-sharing unless used carefully (e.g., padding).  More
importantly, it is very hard to use `threadid`-based approach correctly since
there is no systematic way to locate or restrict yield points.  See also [What
is the difference of `@reduce` and `@init` to the approach using
`state[threadid()]`? · FAQ ·
FLoops](https://juliafolds.github.io/FLoops.jl/dev/explanation/faq/#faq-state-threadid).
}

Let us use the following functions [^cpuvendors] [^details] to demonstrate the effect of
false sharing:

[^cpuvendors]: The effect of false sharing depends on the actual CPU used. This example showed the effect of false sharing when experimented on several CPUs from different vendors (Intel, AMD, and IBM). However, [a simpler example](https://discourse.julialang.org/t/61679) did not show false sharing in some CPUs.

[^details]: Minor details: these functions use `@threads :static` scheduling to force distribution of multiple tasks to the worker (OS) threads. Each array in `yss` includes a space at least as large as a cache line at the end to avoid false sharing as much as possible (although it can be done more parsimoniously).

```julia
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
```

The functions `crowded_inc!` and `exclusive_inc!` perform almost the same
computation and use exactly the same access pattern on the output array `ys` for
each task. In `crowded_inc!`, since multiple tasks (that are likely to be
scheduled on different CPUs) try to update nearby memory locations concurrently,
it invokes false sharing which can be observed as the slow down compared to
`exclusive_inc!` (see below).  This does not occur in `exclusive_inc!` where
each task updates an array dedicated to it (we also made sure that these accesses
are at least one cache line apart).

```julia
julia> using BenchmarkTools

julia> @btime crowded_inc!(ys, data) setup = fill!(ys, 0);
  95.385 ms (43 allocations: 3.70 KiB)

julia> @btime exclusive_inc!(yss, data) setup = foreach(ys -> fill(ys, 0), yss);
  1.801 ms (41 allocations: 3.64 KiB)

julia> versioninfo()
Julia Version 1.6.0
Commit f9720dc2eb (2021-03-24 12:55 UTC)
Platform Info:
  OS: Linux (x86_64-pc-linux-gnu)
  CPU: AMD EPYC 7502 32-Core Processor
  WORD_SIZE: 64
  LIBM: libopenlibm
  LLVM: libLLVM-11.0.1 (ORCJIT, znver2)

julia> Threads.nthreads()
8
```

### Analyzing false sharing using `perf c2c`

If you have a CPU (e.g., Intel) supported by [`perf
c2c`](https://joemario.github.io/blog/2016/09/01/c2c-blog/), it can be used to
detect false sharing.  You can try the following steps or use the script
[`perf_c2c_demo.jl`](https://github.com/JuliaFolds/data-parallelism/blob/master/scripts/perf_c2c_demo.jl)
to analyze the functions we defined above:

1. Create a working directory and `cd` into it.
2. Run `perf c2c record -- --output=crowded_inc-perf.data` (in a different
   system shell session) while invoking `@btime crowded_inc!(ys, data)` in the
   Julia REPL. Terminate it with \kbd{Ctrl}-\kbd{C} when the benchmark is
   finished.
3. Similarly, run `perf c2c record -- --output=exclusive_inc-perf.data` while
   invoking `@btime exclusive_inc!(yss, data)` in the Julia REPL. Terminate it
   with \kbd{Ctrl}-\kbd{C} when the benchmark is finished.
4. Run, e.g., `perf c2c report --input=crowded_inc-perf.data -c tid,iaddr` and
   `perf c2c report --input=exclusive_inc-perf.data -c tid,iaddr` to analyze the
   memory accesses.

An example output of `perf_c2c_demo.jl` can be found at
<https://gist.github.com/01f4793281dc5edee59c9b6cfb05846b>.  See [C2C - False
Sharing Detection in Linux Perf - My Octopress
Blog](https://joemario.github.io/blog/2016/09/01/c2c-blog/) for more information
on `perf c2c` and [Perf Wiki](https://perf.wiki.kernel.org/index.php/Main_Page)
for more information on `perf` in general.

In this example, the command `perf c2c report --input=crowded_inc-perf.data -c
tid,iaddr` shows the false sharing in [this
table](https://gist.github.com/tkf/01f4793281dc5edee59c9b6cfb05846b#file-crowded_inc-perf-txt-L61-L70):

```
=================================================
           Shared Data Cache Line Table
=================================================
#
#        ----------- Cacheline ----------      Tot     …
# Index             Address  Node  PA cnt     Hitm     …
# .....  ..................  ....  ......  .......     …
#                                                      …
      0      0x7f439f2a1ec0     0   62111   15.50%     …
      1      0x7f439f2a1e80     0  134824   14.76%     …
```

The addresses corresponding to these two top *Hitm* (load that hit in a modified
cacheline) are in the output array `ys` (if you use `perf_c2c_demo.jl`, the
addresses are stored in
[`pointers.txt`](https://gist.github.com/tkf/01f4793281dc5edee59c9b6cfb05846b#file-pointers-txt)):

```julia
julia> lower_bound = 0x00007f439f2a1e60;  # pointer(ys, 1)

julia> upper_bound = 0x00007f439f2a1ed8;  # pointer(ys, length(ys))

julia> lower_bound <= 0x7f439f2a1ec0 <= upper_bound  # from: perf c2c report
true

julia> lower_bound <= 0x7f439f2a1e80 <= upper_bound  # from: perf c2c report
true
```

Furthermore, you can find the threads accessing `0x7f439f2a1ec0` by looking at
[another
table](https://gist.github.com/tkf/01f4793281dc5edee59c9b6cfb05846b#file-crowded_inc-perf-txt-L209-L227)
in the output:


```
=================================================
      Shared Cache Line Distribution Pareto
=================================================
#
# ----- HITM -----  -- Store Refs --  ------- CL --------
# RmtHitm  LclHitm   L1 Hit  L1 Miss    Off  Node  PA cnt            Tid      …
# .......  .......  .......  .......  .....  ....  ......  .............      …
#
  -------------------------------------------------------------
      0       21       21    38634    28457      0x7f439f2a1ec0
  -------------------------------------------------------------
   28.57%    9.52%    0.00%    0.00%    0x0     0       1    22239:julia      …
    0.00%    0.00%   26.02%   26.68%    0x0     0       1    22239:julia      …
   33.33%   47.62%    0.00%    0.00%    0x8     0       1    22240:julia      …
    0.00%    0.00%   27.23%   27.08%    0x8     0       1    22240:julia      …
   19.05%   33.33%    0.00%    0.00%   0x10     0       1    22241:julia      …
    0.00%    0.00%   27.33%   27.14%   0x10     0       1    22241:julia      …
   19.05%    9.52%    0.00%    0.00%   0x18     0       1    22242:julia      …
    0.00%    0.00%   19.42%   19.10%   0x18     0       1    22242:julia      …
```

Compare the Tid column above with the list of TIDs of Julia's worker thread (see
[`worker_tids.txt`](https://gist.github.com/tkf/01f4793281dc5edee59c9b6cfb05846b#file-worker_tids-txt)
generated by `perf_c2c_demo.jl`):

```sh
$ cat worker_tids.txt
22234
22236
22237
22238
22239
22240
22241
22242
```

On the other hand, [the
output](https://gist.github.com/tkf/01f4793281dc5edee59c9b6cfb05846b#file-exclusive_inc-perf-txt-L61-L73)
of `perf c2c report
--input=exclusive_inc-perf.data -c tid,iaddr` does not show the sign
of false sharing (Hitm is small and the addresses are outside of `yss[_][_]`):

```
=================================================
           Shared Data Cache Line Table
=================================================
#
#        ----------- Cacheline ----------      Tot      …
# Index             Address  Node  PA cnt     Hitm      …
# .....  ..................  ....  ......  .......      …
#
      0  0xffffffff8d546040     0       1    2.99%      …
      1      0x555ae2321340     0       9    2.99%      …
      2      0x7f43b1a91cc0     0       1    1.80%      …
      3  0xffff95a65fc2cc80     0       1    1.20%      …
      4  0xffffffff8ce44a40     0       1    0.60%      …
      …
```


## Advanced: adjoining trick

While APIs such as `FLoops.@reduce`, `FLoops.@init`, and `Transducers.OnInit`
are useful, not all parallel frameworks support such constructs. Furthermore,
it may be desirable to have even finer grained control; e.g., fusing the
first iteration and the initial value computation.  Fortunately, the basis of
the initial value handling is just a plain algebra concept that can be
implemented with a couple of lines of code.  (See "adjoining" in, e.g.,
[Semigroup -
Wikipedia](https://en.wikipedia.org/wiki/Semigroup#Identity_and_zero).)

First, let us start from a simple case without mutable accumulator. Given a
binary associative function `semigroup` without a (known) identity element, we
can construct a binary function `monoid` with pre-defined identity element:

\input{julia}{/assets/tutorials/mutations/adjoining_trick_1.jl}

(See also [InitialValues.jl](https://github.com/JuliaFolds/InitialValues.jl) as
an implementation of this idea used in JuliaFolds.)

\note{
Even though `asmonod` turns the accumulator type into a small `Union` of types,
the actual base case loop can be very efficient if it uses the [tail-call
"function-barrier"
pattern](https://juliafolds.github.io/Transducers.jl/dev/explanation/state_machines/#tail-call-function-barrier)
to type-stabilize the accumulator type.
}

The function `asmonoid` can be slightly modified to support "in-place semigroup"
with mutable initial value:

\input{julia}{/assets/tutorials/mutations/adjoining_trick_2.jl}

Assuming that the parallel `mapreduce` implementation uses left-to-right
iteration (i.e., left fold; `foldl`) as the base case, the in-place function
`modnoid!` created by `withinit` initializes the accumulator at the first
iteration using the function `f` and re-uses it for each base case.
