# This file was generated, do not modify it. # hide
using Plots
plt = scatter(
    map(collatz_stopping_time, 1:10_000),
    xlabel = "Initial value",
    ylabel = "Stopping time",
    label = "",
    markercolor = 1,
    markerstrokecolor = 1,
    markersize = 3,
    size = (450, 300),
)
savefig(plt, joinpath(@OUTPUT, "collatz_stopping_time_scatter.png")) # hide