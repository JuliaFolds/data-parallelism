# This file was generated, do not modify it. # hide
using Plots
plt = plot(
    collatz_histogram(1:1_000_000),
    xlabel = "Stopping time",
    ylabel = "Counts",
    label = "",
    size = (450, 300),
)
savefig(plt, joinpath(@OUTPUT, "plot_hist_collatz_stopping_time.png")) # hide