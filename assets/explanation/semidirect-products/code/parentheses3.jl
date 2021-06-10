# This file was generated, do not modify it. # hide
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