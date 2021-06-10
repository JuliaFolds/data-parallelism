# This file was generated, do not modify it. # hide
function provide(body, request)
    endpoint(x) = call(request, x)
    try
        body(endpoint)
    finally
        close(request)
    end
end

function define_service(f; kwargs...)
    open_service(body) = provide(body, raw_service(f; kwargs...))
    return open_service
end