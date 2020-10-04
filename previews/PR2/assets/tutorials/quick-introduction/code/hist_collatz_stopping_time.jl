# This file was generated, do not modify it. # hide
using FLoops
using MicroCollections: SingletonDict

maxkey(xs::AbstractVector) = lastindex(xs)
maxkey(xs::SingletonDict) = first(keys(xs))

function collatz_histogram(xs, executor = ThreadedEx())
    @floop executor for x in xs
        n = collatz_stopping_time(x)
        n > 0 || continue
        obs = SingletonDict(n => 1)
        @reduce() do (hist = Int[]; obs)
            l = length(hist)
            m = maxkey(obs)  # obs is a Vector or SingletonDict
            if l < m
                # Stretch `hist` so that the merged result fits in it.
                resize!(hist, m)
                fill!(view(hist, l+1:m), 0)
            end
            # Merge `obs` into `hist`:
            @floop for (k, v) in pairs(obs)
                @inbounds hist[k] += v
            end
        end
    end
    return hist
end

# Example usage:
using Plots
plt = plot(
    collatz_histogram(1:1_000_000),
    xlabel = "Stopping time",
    ylabel = "Counts",
    label = "",
    size = (450, 300),
)
savefig(plt, joinpath(@OUTPUT, "hist_collatz_stopping_time.png")) # hide