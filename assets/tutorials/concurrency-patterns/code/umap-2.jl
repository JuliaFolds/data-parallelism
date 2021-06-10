# This file was generated, do not modify it. # hide
function umap(f, TY::Type, xs; kwargs...)
    @assert !(xs isa Channel)  # hide
    ch = Channel{eltype(xs)}() do ch
        for x in xs
            put!(ch, x)
        end
    end
    return umap(f, TY, ch; kwargs...)
end