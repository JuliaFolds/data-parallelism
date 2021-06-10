# This file was generated, do not modify it. # hide
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