# Parallel reductions using semidirect products

Solutions to many parallel programming problems can be reduced to a
well-designed monoid[^semigroup]. As such, interesting parallel solution
sometimes require non-trivial monoids. To enrich the repertoire, let us discuss
_semidirect product_; a particularity elegant construction of useful monoids.

\tableofcontents

[^semigroup]: Here, we mainly discuss monoid and monoid actions. However, since one can always turn a semigroup into a monoid by adjoining the identity, the following discussion also applies to semigroups which is more useful than monoid in dynamic languages like Julia.

\note{
The code examples here focus on simplicity rather than the performance and
actually executing them in parallel.  However, it is straightforward to use
exactly the same pattern and derive efficient implementations in Julia.  See
[A quick introduction to data parallelism in Julia](../../tutorials/quick-introduction/) and
[Efficient and safe approaches to mutation in data parallelism](../../tutorials/mutations/)
for the main ingredients required.
}

\label{maxdepth}
## Maximum depth of parentheses

As a motivating example, let us compute the maximum depth of parentheses in a
string. Each position of a string has an integer _depth_ which is one more
larger (smaller) than the depth of the previous position if the current
character is the open parenthesis `(` (close parenthesis `)`). Otherwise the
depth is equal to the depth of the previous position. The initial depth is 0.
We are interested in the maximum depth of a given string:

```plaintext
string    (  (  (  )  )  (  )  )
depth     1  2  3  2  1  2  1  0
                ↑
                maximum depth
```

The following code is a Julia program that calculates the maximum depth.  It
computes the depth of every position using the cumulative sum function `cumsum`
and then take the `maximum` of it:

```julia:parentheses1
parentheses = collect("(((())((()))) ((())))")
increments = ifelse.(parentheses .== '(', +1, ifelse.(parentheses .== ')', -1, 0))
depths = cumsum(increments)
maximum(depths)
```

\show{parentheses1}

```julia:parentheses2
# hideall
using Plots

function plot_maxdepth(parentheses; xs = eachindex(parentheses), suffix = "")
    parentheses = collect(parentheses)
    increments = ifelse.(parentheses .== '(', +1, ifelse.(parentheses .== ')', -1, 0))
    depths = cumsum(increments)
    dmax, imax = findmax(depths)
    imax += first(xs) - 1
    plt_depth = plot(
        [first(xs)-1; xs],
        [0; depths],
        seriestype = :steppost,
        label = "",
        ylabel = "depths" * suffix,
        ylim = (min(0, minimum(depths)), maximum(depths) + 2),
    )
    plot!(
        plt_depth,
        [imax],
        [dmax],
        label = "",
        markershape = :o,
        # xticks = nothing,
        annotations = (
            imax - 2,
            dmax + 0.5,
            text("maximum(depths$suffix)", :left, :bottom),
        ),
    )
    plt_inc = bar(
        xs,
        increments,
        label = "",
        ylabel = "increments" * suffix,
        xticks = (xs, parentheses),
        yticks = [-1, 0, 1],
    )
    plt = plot(
        plt_depth,
        plt_inc,
        layout = (:, 1),
        link = :x,
    )
    return plt
end
savefig(plot_maxdepth(parentheses), joinpath(@OUTPUT, "parentheses2.png"))
```

```julia:parentheses3
# hideall
using Plots

function plot_depths(parentheses; xs = eachindex(parentheses), suffix = "", kwargs...)
    parentheses = collect(parentheses)
    increments = ifelse.(parentheses .== '(', +1, ifelse.(parentheses .== ')', -1, 0))
    depths = cumsum(increments)
    dmax, imax = findmax(depths)
    imax += first(xs) - 1
    plt_depth = plot(; xlim = (first(xs)-1, last(xs)+1), kwargs...)
    hline!(
        plt_depth,
        [0];
        color = :black,
        linestyle = :dot,
        label = "",
        
    )
    plot!(
        plt_depth,
        [first(xs)-1; xs],
        [0; depths];
        color = 1,
        seriestype = :steppost,
        label = "",
    )
    plot!(
        plt_depth,
        [imax],
        [dmax],
        color = 2,
        label = "",
        markershape = :o,
        # xticks = nothing,
        annotations = (
            imax,
            dmax + 0.5,
            text("m$suffix", :left, :bottom),
        ),
    )
    plot!(
        plt_depth,
        [xs[end]],
        [depths[end]],
        color = 3,
        label = "",
        markershape = :rect,
        # xticks = nothing,
        annotations = (
            xs[end] + 0.4,
            depths[end],
            text("d$suffix", :left),
        ),
    )
    # plot!(
    #     plt_depth,
    #     [xs[end], xs[end]] .+ 0.5,
    #     [0, depths[end]],
    #     arrow = true,
    #     label = "",
    # )
    return plt_depth
end

function depth_and_maximum(parentheses)
    parentheses = collect(parentheses)
    increments = ifelse.(parentheses .== '(', +1, ifelse.(parentheses .== ')', -1, 0))
    depths = cumsum(increments)
    return (depths[end], maximum(depths))
end

let
    m = length(parentheses) ÷ 3
    ymin, ymax = extrema([0; depths])
    ylim = (ymin - 1, ymax + 2)
    chunk1 = parentheses[1:m]
    chunk2 = parentheses[m+1:2m]
    chunk3 = parentheses[2m+1:end]

    global d1, m1 = depth_and_maximum(chunk1)
    global d2, m2 = depth_and_maximum(chunk2)
    global d3, m3 = depth_and_maximum(chunk3)

    plt = plot(
        plot_depths(chunk1; suffix = 1, title = "chunk 1", ylim),
        plot_depths(chunk2; xs = m+1:2m, suffix = 2, ylim = ylim .- depths[m], title = "chunk 2"),
        plot_depths(chunk3; xs = 2m+1:length(parentheses), suffix = 3, ylim = ylim .- depths[2m], title = "chunk 3"),
        layout = (1, :),
        size = (800, 200),
    )
    savefig(plt, joinpath(@OUTPUT, "parentheses3.png"))
end
```

\fig{parentheses2.png}

Both `cumsum` (prefix sum) and `maximum` (reduce) can be computed in parallel.
However, it is possible to fuse these operations and compute the maximum depth
in one sweep (which is essential for performance). To solve this problem with
single-path reduction, we need to find a small set of states "just enough" for
combining sub-solutions obtained by solving each chunk of the input.  An
important observation here is that the "humps" in the `depths` plot can be
easily shifted up and down when combining into the result from preceding (left)
string of parentheses. This motivates us to track the maximum and the final
(relative) depth of a chunk of the input string. Splitting the above solution
into three chunks, we get the following three sub-solutions:

\fig{parentheses3.png}

Consider chunk 1 and 2.  Combining the final depths (`d1` and `d2`) is as easy
as summing these two depths.  To combine the maximum in each chunk, we need to
shift the right maximum `m2` by the final depth of the left chunk `d1` so that
both maximum "candidates" `m1` and `m2` are compared with respect to the same
reference point (i.e., the beginning of the left chunk).  Thus, we get the
following function for combining the solutions `(d1, m1)` and `(d2, m2)` from
two consecutive chunks:

```julia:parentheses4
function ⊗((d1, m1), (d2, m2))
    d = d1 + d2           # total change in depth

    m2′ = d1 + m2         # shifting the maximum of the right chunk before comparison
    m = max(m1, m2′)      # find the maximum

    return (d, m)
end
```

Given the sub-solutions above

```julia:parentheses5
#hideall
@show d1, m1
@show d2, m2
@show d3, m3
```

\output{parentheses5}

we can compute the final result

```julia:parentheses6
ans = begin # hide
(d1, m1) ⊗ (d2, m2) ⊗ (d3, m3)
end # hide
@assert ans[2] == maximum(depths) # hide
ans # hide
```

\show{parentheses6}

where the second element of the tuple is the maximum depth.  As we will see in
the next section, `⊗` is associative.  Thus, we can use it as the input to
`reduce`. Observing singleton chunk `[x]` (where `x` is -1, 0, or 1) has the
trivial solution `(x, x)` (i.e., the last element of `[x]` is `x` and the
maximum element of `[x]` is `x`), we get the single-sweep reduction to calculate
the maximum depth of the parentheses:

```julia:parentheses7
ans = begin # hide
mapreduce(x -> (x, x), ⊗, increments)
end # hide
@assert ans[2] == maximum(depths) # hide
ans # hide
```

\show{parentheses7}

Recall that `mapreduce` can also be computed using the left-fold `mapfoldl`.  By
manually inlining the definitions of `mapfoldl(x -> (x, x), ⊗, increments)`, we
also obtain the following sequential algorithm:

```julia
function maxdepth_seq1(increments)
    d1 = m1 = 0
    for x in increments
        d2 = m2 = x

        # Inlining `⊗`:
        d = d1 + d2
        m2′ = d1 + m2
        m = max(m1, m2′)

        d1 = d
        m1 = m
    end
    return m1
end
```

Since `d1 + d2` and `d1 + m2` are equivalent when `d2 = m2 = x`, we can do
"manual Common Subexpression Elimination" to get:

```julia
function maxdepth_seq2(increments)
    d1 = m1 = 0
    for x in increments
        d1 = d1 + x
        m1 = max(m1, d1)
    end
    return m1
end
```

Note that this is the straightforward sequential solution to the original
problem. Compilers such as Julia+LLVM may be able to do this "derivation"
as a part of optimization in may programs. It is also possible to implement this
with sufficiently rich "monoid combinator" frameworks such as
[Transducers.jl](https://github.com/JuliaFolds/Transducers.jl) (using `next` and
`combine` specializations).

## Semidirect products (restricted version)

The structure in `⊗` of the previous section is actually very generic and
applicable to many other reductions. If we replace `+` with `*′` and `max` with
`+′`, we obtain the following higher-order function (combinator) `sdpl`. Let us
also define a similar "flipped" version `sdpr`.

```julia:sdp1
sdpl(*′, +′) = ((a₁, b₁), (a₂, b₂)) -> (a₁ *′ a₂, b₁ +′ (a₁ *′ b₂))
sdpr(*′, +′) = ((a₁, b₁), (a₂, b₂)) -> (a₁ *′ a₂, (b₁ *′ a₂) +′ b₂)
```

A binary function `(x, y) -> sdpl(*′, +′)(x, y)` is associative (i.e.,
semigroup) if `*′` and `+′` are both associative and `*′` is left-distributive
over `+′`; i.e.,

\label{eq-distl-op}
$$
\tag{distl-op}
x *' (y +' z) = (x *' y) +' (x *' z)
$$

Similarly, `sdpr(*′, +′)` is associative if `*′` and `+′` are both associative
and `*′` is right-distributives over `+′`.  See, e.g., [Kogge and Stone (1973)],
[Blelloch (1990)], [Gorlatch and Lengauer (1997)], [Chauhan et al. (2016)], and
[Kmett (2018)] for the discussion and applications on this algebraic fact (or
its generalized form; see below).  The monoid combinator `sdpl` of this form in
particular is described in [Gorlatch and Lengauer (1997)], including the proofs
we skipped here. They described it as _scan-reduce composition_ and _scan-scan
composition_ theorems.  As we saw in the previous section, `mapreduce(x -> (x,
x), sdpl(+, max), increments)` computes `maximum(cumsum(increments))`
efficiently by composing (fusing) the scan (`cumsum`) and reduce (`maximum`).

Borrowing the terminology from group theory (see [Semidirect product -
Wikipedia](https://en.wikipedia.org/wiki/Semidirect_product)), and also
following [Chauhan et al. (2016)]'s nomenclature, let us call `sdpl` and `sdpr`
the _semidirect products_ although the definition above is not of its fully
generalized form.

Other than the usual multiplication-addition pair (`*`, `+`) and addition-max
pair (`+`, `max`) as discussed in the previous section, there are various pairs
of monoids satisfying left- and/or right-distributivity property (see,
[Distributive property -
Wikipedia](https://en.wikipedia.org/wiki/Distributive_property)).  For example,
following functions can be used with `sdpl` and `sdpr` (on appropriate domain
types):

| `*′`  | `+′`  | Example applications |
| ---   | ---   | --- |
| `*`   | `+`   | linear recurrence (see below) |
| `+`   | `max` | maximum depth of parentheses (see above) |
| `+`   | `min` |   |
| `min` | `max` |   |
| `max` | `min` |   |
| `∩`   | `∪`   | `unique` (see below); GEN/KILL-sets |
| `∪`   | `∩`   |   |

The `unique` example (below) and GEN-/KILL-sets example in [Chauhan et al.
(2016)] can be considered an instance of `sdpl(∩, ∪)` with the first monoid `∩`
virtually operating on the complement sets.

## Linear recurrence

Semidirect product `sdpr(*′, +′)` is a generalized from of linear recurrence
equation:

\label{eq-linrec}
$$
\tag{linrec}
x_t = x_{t-1} a_t + b_t  \qquad (t=1,2,...,T)
$$

given sequences $(a_t)_{t=1}^{T}$ and $(b_t)_{t=1}^T$.  Let us use the initial
condition $x_0 = 0$ for simplicity (as specifying $x_0$ is equivalent to
specifying $b_1$). Indeed, `(1, 0)` is the identity element for the method
`sdpr(*, +)(_::Number, _::Number)`.  To see `sdpr(*, +)` computes
$(x_t)_{t=1}^T$, let us manually expand `foldl(sdpr(*, +), zip(as, bs); init =
(1, 0))`, as we did for `maxdepth_seq1` (or, alternatively, see [Blelloch
(1990)]):

```julia
function linear_recurrence_seq1(as, bs)
    a₁ = 1
    b₁ = 0
    for (a₂, b₂) in zip(as, bs)
        # Inlining `sdpr(*, +)`:
        a₁ = a₁ * a₂
        b₁ = b₁ * a₂ + b₂
    end
    return (a₁, b₁)
end
```

By eliminating `a₁` and renaming `b₁` to `x`, we have

```julia
function linear_recurrence_seq2(as, bs)
    x = 0
    for (a, b) in zip(as, bs)
        x = x * a + b
    end
    return x
end
```

which computes the linear recurrence equation [(linrec)](#eq-linrec).
(Note: the first component `a₁ * a₂` is still required for associativity of
`sdpr(*, +)`. It keeps track of the multiplier $\prod_{t=p}^q a_t$ for
propagating the effect of $x_{p-1}$ to $x_q$.)

The above code also work when the elements in `as` and `bs` are matrices.  In
particular, `x` and `b` can be "row vectors." Even though Julia uses 1×n
matrices for row vectors, this observation indicates that `a`s and `b`s can live
in different spaces. Indeed, we will see that it is useful to "disassociate" the
functions for `a₁ *′ a₂` and `b₁ *′ a₂`.

## Semidirect products and distributive monoid actions

The combinators `sdpl` and `sdpr` can be generalized to the case where `a`s and
`b`s are of different types.  We can simply extend these combinators to take
three functions[^multipledispatch] :

```julia:sdp2
sdpl(*′, ⊳, +′) = ((a₁, b₁), (a₂, b₂)) -> (a₁ *′ a₂, b₁ +′ (a₁ ⊳ b₂))
sdpr(*′, ⊲, +′) = ((a₁, b₁), (a₂, b₂)) -> (a₁ *′ a₂, (b₁ ⊲ a₂) +′ b₂)
```

[^multipledispatch]: In Julia, we acn use multiple dispatch for plumbing the calls `a₁ *′ a₂` and `b₁ *′ a₂` to different implementations. However, it would require defining particular type for each pair of `a₁ *′ a₂` and `b₁ *′ a₂`.  Thus, it is more convenient to define these ternary combinators.

The binary function `(x, y) -> sdpl(*′, ⊳, +′)(x, y)` is a monoid if `*′` and
`+′` are monoids, the function `⊳` is a left _monoid action_[^semigroupaction];
i.e., it satisfies

\label{eq-actl}
$$
\tag{actl}
a_1 \rhd (a_2 \rhd b) = (a_1 *' a_2) \rhd b
$$

and it is left-_distributive_ over `+'`; i.e.,

\label{eq-distl-act}
$$
\tag{distl-act}
a \rhd (b_1 +' b_2) = (a \rhd b_1) +' (a \rhd b_2).
$$

The first condition indicates we can either

1. apply actions sequentially (e.g., $A_1 (A_2 x)$ where $A_1$ and $A_2$ are
   matrices and $x$ is a vector) or
2. combine actions first and _then_ apply the combined function (e.g., $(A_1
   A_2) x$).

The second condition indicates that we can either

1. merge the "targets" $b_1$ and $b_2$ first (e.g., $A (x_1 + x_2)$ where $A$ is
   a matrix and $x_1$ and $x_2$ are vectors) or
2. apply the actions separately and _then_ merge them (e.g., $A x_1 + A x_2$).

These extra freedom in how to compute the result is essential in the parallel
computing and is captured by the property that `(x, y) -> sdpl(*′, ⊳, +′)(x, y)`
is associative.

If $*' = \rhd$, the condition for monoid action [(actl)](#eq-actl) is simply the
associativity condition and the condition for left-distributivity of the monoid
action [(distl-act)](#eq-distl-act) is equivalent to the left-distribuity of the
modnoid [(distl-op)](#eq-distl-op).

For `sdpr(*′, ⊲, +′)`, the function `⊲` must be a right monoid action

\label{eq-actr}
$$
\tag{actr}
(b \lhd a_1) \lhd a_2 = b \lhd (a_1 *' a_2)
$$

that right-distributes over `+'`

\label{eq-distr-act}
$$
\tag{distr-act}
(b_1 +' b_2) \lhd a = (b_1 \lhd a) +' (b_2 \lhd a).
$$

This construction of monoids `sdpl(*′, ⊳, +′)` and `sdpr(*′, ⊲, +′)` are called
[_semidirect
product_](https://en.wikipedia.org/wiki/Semidirect_product)[^semiassociative].

[^semigroupaction]: It may be easier to find the resources on [semigroup action](https://en.wikipedia.org/wiki/Semigroup_action). A monoid action is simply a semigroup action that is also a monoid.

[^semiassociative]: [Kogge and Stone (1973)] and [Blelloch (1990)] use the term _semiassociative_ for describing the property required for the function `⊲`.

As an aside, observe that more "obvious" way to combine two monoids (i.e.,
direct product)

```julia:prodop
prodop(⊗₁, ⊗₂) = ((xa, xb), (ya, yb)) -> (xa ⊗₁ ya, xb ⊗₂ yb)

ans = begin # hide
mapreduce(x -> (x, x), prodop(+, *), 1:10; init = (0, 1))  # example
end # hide
ans == (sum(1:10), prod(1:10)) # hide
ans # hide
```

\show{prodop}

is a special case of semidirect product with trivial "do-nothing" actions `a ⊳ b
= b` or `b ⊲ a = b`.

## Order-preserving `unique`

Julia's
[`unique`](https://docs.julialang.org/en/v1/base/collections/#Base.unique)
function returns a vector of unique element in the input collection while
preserving the order that the elements appear in the input.  To parallelize this
function, we track the unique elements in a set and also keep the elements in a
vector to maintain the ordering. When combining two solutions, we need to filter
out elements in the right chunk if they already appear in the left chunk. This
can be implemented by using `setdiff` for the left action on the vector.

```julia:unique1
function vector_unique(xs)
    singletons = ((Set([x]), [x]) for x in xs)
    monoid = sdpl(union, (a, b) -> setdiff(b, a), vcat)
    return last(reduce(monoid, singletons))
end
```

Example:

```julia:unique2
vector_unique([1, 2, 1, 3, 1, 2, 1])
```

\show{unique2}

## Most nested position of parentheses

Using the general form of semidirect product, we can compute the maximum depth
of parentheses and the corresponding index ("key"). It can be done with a
function `maxpair` that keeps track of the maximum value and the index in the
second monoid. The action `shiftvalue` can be used to shift the value but not
the index:

```julia:findmax_parentheses
maxpair((i, x), (j, y)) = y > x ? (j, y) : (i, x)
shiftvalue(d, (i, x)) = (i, d + x)

function findmax_parentheses(increments)
    singletons = ((x, (i, x)) for (i, x) in pairs(increments))
    monoid = sdpl(+, shiftvalue, maxpair)
    return reduce(monoid, singletons)[2]
end

ans = begin # hide
findmax_parentheses(increments)
end # hide
@assert ans == (9, 5) # hide
ans # hide
```

\show{findmax_parentheses}

(Compare this result with [the first section](#maxdepth).)

In the above example, we assumed that the key (position/index) is cheap to
compute.  However, we may need to use reduction to compute the key as well. For
example, the input may be a UTF-8 string and we need the number of characters
(code points) as the key. Another situation that this is requried is when
processsing newline delimited strings and we need the line column (and/or the
line number) as the key. We can compute the index on-the-fly by **applying
`sdpl` twice**.  The "inner" application is the monoid used in the
`findmax_parentheses` function above. The "outer" application of `sdpl` is used
to for 1️⃣ counting the processed number of elemetns and 2️⃣ shifting the index
using the left action:

```julia:findmax_parentheses_relative
shiftindex(n, (d, (i, x))) = (d, (n + i, x))
#                                 ~~~~~
#          shift the index i by the number n of processed elements

function findmax_parentheses_relative(increments)
    singletons = ((1, (x, (1, x))) for x in increments)
    #              |       |
    #              |      the index of the maximum element in a singleton collection
    #             the number of elements in a singleton collection

    monoid = sdpl(+, shiftindex, sdpl(+, shiftvalue, maxpair))
    #             ~  ~.~~~~~~~~  ~~~.~~~~~~~~~~~~~~~~~~~~~~~~
    #             |   |              `-- compute maximum of depths and its index (as above)
    #             |   |
    #             |   `-- 2️⃣ shift the index of right chunk by the size of processed left chunk
    #             |
    #              `-- 1️⃣ compute the size of processed chunk

    return reduce(monoid, singletons)[2][2]
end

ans = begin # hide
findmax_parentheses_relative(increments)
end # hide
@assert ans == (9, 5) # hide
ans # hide
```

\show{findmax_parentheses_relative}

Since `shiftindex` acts only on the index portion of the state of `sdpl(+,
shiftvalue, maxpair)` and the index does not interact with the other components,
it is easy to see that this satisfy the condition for semidirect product.


\test{findmax_parentheses_relative}{

    # ...which does not mean we shouldn't be unit-testing it
    using Test
    @testset begin
        ⊗ = sdpl(+, shiftindex, sdpl(+, shiftvalue, maxpair))
        prod3(xs) = Iterators.product(xs, xs, xs)
        nfailed = 0
        for (n1, n2, n3) in prod3(1:3),
                (d1, d2, d3) in prod3(1:3),
                (i1, i2, i3) in prod3('a':'c'),
                (m1, m2, m3) in prod3(1:3)
            x1 = (n1, (d1, (i1, m1)))
            x2 = (n2, (d2, (i2, m2)))
            x3 = (n3, (d3, (i3, m3)))
            nfailed += !(x1 ⊗ (x2 ⊗ x3) == (x1 ⊗ x2) ⊗ x3)
        end
        @test nfailed == 0
    end

}

<!--
```julia
function findmax_parentheses_relative_monoid((n1, (d1, (i1, m1))), (n2, (d2, (i2, m2))))
    n = n1 + n2
    d = d1 + d2
    i2′ = n1 + i2
    m2′ = d1 + m2
    i, m = maxpair((i1, m1), (i2′, m2′))
    return (n, (d, (i, m)))
end
```
-->

## Conclusion

Semidirect products appear naturally in reductions where multiple states
interact.  It helps us easily derive efficient and intricate parallel programs.
Furthermore, even if semidirect product is not required to derive the monoid, it
is cumbersom to convince oneself that the given definition and implementation of
the monoid indeed satisfy the algebraic requirements.  Decomposing the monoid
into simpler "sub-component" monoids and monoid actions makes it easy to reason
about such algebraic properties.

## References

[Kogge and Stone (1973)]: #kogge1973
[Blelloch (1990)]: #blelloch1990
[Gorlatch and Lengauer (1997)]: #gorlatch1997
[Chauhan et al. (2016)]: #chauhan2016
[Kmett (2018)]: #kmett2018

* \label{kogge1973} Kogge, Peter M., and Harold S. Stone. 1973. “A Parallel Algorithm for the Efficient Solution of a General Class of Recurrence Equations.” IEEE Transactions on Computers C–22 (8): 786–93. <https://doi.org/10.1109/TC.1973.5009159>.

* \label{Blelloch1990} Blelloch, Guy E. “Prefix Sums and Their Applications,” 1990, 26.  <https://kilthub.cmu.edu/articles/journal_contribution/Prefix_sums_and_their_applications/6608579/1>

* \label{Gorlatch1997} Gorlatch, S., and C. Lengauer. “(De) Composition Rules for Parallel Scan and Reduction.” In Proceedings. Third Working Conference on Massively Parallel Programming Models (Cat. No.97TB100228), 23–32, 1997. <https://doi.org/10.1109/MPPM.1997.715958>.

* \label{chauhan2016} Chauhan, Satvik, Piyush P. Kurur, and Brent A. Yorgey. 2016. “How to Twist Pointers without Breaking Them.” In Proceedings of the 9th International Symposium on Haskell, 51–61. Haskell 2016. New York, NY, USA: Association for Computing Machinery. <https://doi.org/10.1145/2976002.2976004>.

* \label{kmett2018} Kmett, Edward. 2018. “There and Back Again.” Presented at the Lambda World, Seattle, USA. <https://www.youtube.com/watch?v=HGi5AxmQUwU>.
