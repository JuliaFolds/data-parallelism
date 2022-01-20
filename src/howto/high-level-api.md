# How to find data-parallel algorithms

\note{Work in progress}

[Alternative intro (maybe this is better)]

When there is a library function that provides an algorithm for what you want to
compute, it is usually a good idea to use it. Although this is true for parallel
programming as well, it may not be obvious what functions are provided by the
libraries as it requires the knowledge of what can be parallelized. This how-to
guide tries to provide a simplified overview for finding data-parallel library
functions.

---

Julia provides `@spawn` as a basic building block for parallelism and
[FLoops.jl](https://github.com/JuliaFolds/FLoops.jl) provides generic parallel
`for` loop syntax. However, they are often too "low-level" as an API for
building parallel programs.  To make writing parallel programs simpler,
[Folds.jl](https://github.com/JuliaFolds/Folds.jl) and
[ThreadsX.jl](https://github.com/tkf/ThreadsX.jl) provide basic "high-level"
algorithms similar to Julia's
[`Base`](https://docs.julialang.org/en/v1/base/base/) library as described
below. High-level APIs can be used for expressing *what* you want to compute
which aids not only understandability and maintainability of the program but
also the efficiency of the program because the library implementers can use
adequate strategy for *how* to compute the result.

If you are familiar with the functions listed in Folds.jl and ThreadsX.jl, no
further explanations are required for start using them.  However, since not all
`Base` functions are parallelizable, it may be hard to remember which functions
are supported by these libraries. This how-to guide tries to provide a simple
"guide map" for navigating the functions provided by Folds.jl and ThreadsX.jl,
as summarized in the following picture:

![guide map](https://gist.githubusercontent.com/tkf/5012bd2e12f584ec8b6092476912c907/raw/folds.svg)

TODO: `cumprod!(ys)` -> `cumprod!(ys, xs)`

<!--

```
map(f, xs)
map!(f, ys, xs)
foreach(f, xs)

reduce(op, xs)
sum(xs)
prod(xs)
all(xs)
any(xs)
count(xs)
maximum(xs)
minimum(xs)
extrema(xs)
issorted(xs)

mapreduce(f, op, xs)
sum(f, xs)
prod(f, xs)
all(f, xs)
any(f, xs)
count(f, xs)
maximum(f, xs)
minimum(f, xs)
extrema(f, xs)
issorted(xs; by = f)

findmax(f, xs)
findmin(f, xs)
argmax(f, xs)
argmin(f, xs)
findall(f, xs)
findfirst(f, xs)
findlast(f, xs)

collect(xs)
unique(xs)
set(xs)
dict(xs)

accumulate(op, xs)
accumulate!(op, ys, xs)
cumsum(xs)
cumsum!(ys, xs)
cumprod(xs)
cumprod!(ys)
scan!(op, xs)
```
-->

The above picture is only very superficially accurate and you may need to
"unlearn" it to use these libraries in full extent. However, it is a good
approximation for start using

\tableofcontents

## Independent computation (`map`-family)

Given an array `xs` with elements $x_1, x_2, ..., x_n$...

| Function          | Returns |
| :---              | :--- |
| `map(f, xs)`      | $[f(x_1), f(x_2), ..., f(x_n)]$ |
| `map!(f, ys, xs)` | ditto, but stores the result in `ys` |
| `foreach(f, xs)`  | runs $f(x_i)$ in parallel for side-effect |

TODO: explanations, examples, ...

## Simple reductions (`reduce`-family)

| Function         | Returns |
| :---             | :--- |
| `reduce(⊗, xs)`  | $x_1 \otimes x_2 \otimes ... \otimes x_n$ |
| `sum(xs)`        | $x_1 + x_2 + ... + x_n$ |
| `prod(xs)`       | $x_1 * x_2 * ... * x_n$ |
| `all(xs)`        | $x_1 \;\&\; x_2 \;\&\; ... \;\&\; x_n$ |
| `any(xs)`        | $x_1 \;|\; x_2 \;|\; ... \;|\; x_n$ |
| `count(xs)`      | $x_1 + x_2 + ... + x_n$ |
| `maximum(xs)`    | $\texttt{max}(x_1, x_2, ..., x_n)$ |
| `minimum(xs)`    | $\texttt{min}(x_1, x_2, ..., x_n)$ |
| `extrema(xs)`    | `(minimum(xs), maximum(xs))` |
| `issorted(xs)`   | $(x_1 \le x_2) \;\&\; (x_2 \le x_3) \;\&\; ... \;\&\; (x_{n-1} \le x_n)$ |

## Element-wise computation fused with simple reductions (`mapreduce`-family)

| Function               | Returns |
| :---                   | :--- |
| `mapreduce(f, ⊗, xs)`  | $f(x_1) \otimes f(x_2) \otimes ... \otimes f(x_n)$ |
| `sum(f, xs)`           | $f(x_1) + f(x_2) + ... + f(x_n)$ |
| `prod(f, xs)`          | $f(x_1) * f(x_2) * ... * f(x_n)$ |
| `all(f, xs)`           | $f(x_1) \;\&\; f(x_2) \;\&\; ... \;\&\; f(x_n)$ |
| `any(f, xs)`           | $f(x_1) \;|\; f(x_2) \;|\; ... \;|\; f(x_n)$ |
| `count(f, xs)`         | $f(x_1) + f(x_2) + ... + f(x_n)$ |
| `maximum(f, xs)`       | $\texttt{max}(f(x_1), f(x_2), ..., f(x_n))$ |
| `minimum(f, xs)`       | $\texttt{min}(f(x_1), f(x_2), ..., f(x_n))$ |
| `extrema(f, xs)`       | `(minimum(xs), maximum(xs))` |
| `issorted(xs; by = f)` | $(f(x_1) \le f(x_2)) \;\&\; (f(x_2) \le f(x_3)) \;\&\; ... \;\&\; (f(x_{n-1}) \le f(x_n))$ |

## Searching

| Function           | Returns |
| :---               | :--- |
| `findmax(f, xs)`   | `(x, index)` s.t. `xs[index] == x == maximum(f, xs)` |
| `findmin(f, xs)`   | `(x, index)` s.t. `xs[index] == x == minimum(f, xs)` |
| `argmax(f, xs)`    | `x` s.t. `f(x) == maximum(f, xs)` |
| `argmin(f, xs)`    | `x` s.t. `f(x) == minimum(f, xs)` |
| `findall(f, xs)`   | `indices` such that `f(xs[i])` holds iff `i` in `indices` |
| `findfirst(f, xs)` | first `i` s.t. `f(xs[i])` holds; `nothing` if not found |
| `findlast(f, xs)`  | last `i` s.t. `f(xs[i])` holds; `nothing` if not found |

## Scan (`accumulate`-family)

| Function                 | Returns |
| :---                     | :--- |
| `accumulate(⊗, xs)`      | $[x_1, x_1 \otimes x_2, x_1 \otimes x_2 \otimes x_3, ...]$ |
| `accumulate!(⊗, ys, xs)` | ditto, but stores the result in `ys` |
| `scan!(⊗, xs)`           | ditto, but stores the result in `xs` |
| `cumsum(xs)`             | $[x_1, x_1 + x_2, x_1 + x_2 + x_3, ...]$ |
| `cumsum!(ys, xs)`        | ditto, but stores the result in `ys` |
| `cumprod(xs)`            | $[x_1, x_1 * x_2, x_1 * x_2 * x_3, ...]$ |
| `cumprod!(ys, xs)`       | ditto, but stores the result in `ys` |

## Generating data structure (`collect`-family)

In above sections, we pretended that `xs` is an array. However, there various
*collection* of items in Julia. We can turn sufficiently well-behaving such
collections into an array in parallel using `Folds.collect`.  It is also
possible to collect only unique elements using `Folds.unique`.  The output data
structure does not have to be an array.  We can use `Folds.set` to create a set
of elements.  If there is no need to preserve the ordering of the input, it is
more efficient than `Folds.unique`.  Given a collection of `Pair`s, we can use
`Folds.dict` to create a dictionary.

| Function      | Returns |
| :---          | :--- |
| `collect(xs)` | collect elements of `xs` into an array |
| `unique(xs)`  | collect unique elements of `xs` into an array, preserving the order |
| `set(xs)`     | collect elements of `xs` into a set |
| `dict(xs)`    | collect elements of `xs` into a dictionary |

## Flexible preprocessing

```
xs = (f(y) for x in collection if p(x) for y in g(x))
#     ----                     ------- -------------
#     mapping               filtering  flattening
```

See also:
[A quick introduction to data parallelism in Julia](../../tutorials/quick-introduction)

## Folds.jl vs ThreadsX.jl: which one to use?

ThreadsX.jl provides a similar interface like Folds.jl but it is specific to
multi-core -based parallelism.  Furthermore, it provides algorithms such as
`sort!` that cannot be easily expressed as a simple invocation of `reduce`.

Folds.jl focuses on algorithms expressible in terms of a generalized `reduce`.
