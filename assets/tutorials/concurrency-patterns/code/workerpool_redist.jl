# This file was generated, do not modify it. # hide
function workerpool_redist(work!, allocate, request; kwargs...)
    workerpool(allocate, request; kwargs...) do input, resource
        wait(@spawn work!(input, resource))
    end
end