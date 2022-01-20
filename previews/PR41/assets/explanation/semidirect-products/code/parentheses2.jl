# This file was generated, do not modify it. # hide
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