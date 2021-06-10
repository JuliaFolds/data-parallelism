# This file was generated, do not modify it. # hide
function raw_service(f; ntasks = Threads.nthreads())
    request = Channel() do request
        @sync for _ in 1:ntasks
            @spawn for (x, promise) in request
                y = f(x)
                put!(promise, y)
            end
        end
    end
    return request
end

function call(request, x)
    promise = Channel(1)
    put!(request, (x, promise))
    return take!(promise)
end

adder = raw_service() do x
    return x + 1
end
try
    @assert call(adder, 0) == 1
    @assert call(adder, 1) == 2
finally
    close(adder)
end