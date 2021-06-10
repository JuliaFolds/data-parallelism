# This file was generated, do not modify it. # hide
function define_single_thread_service(f)
    function open_service(body)
        request = Channel() do request
            for (x, promise) in request
                y = f(x)
                put!(promise, y)
            end
        end
        provide(body, request)
    end
    return open_service
end

with_adder = define_single_thread_service() do x
    return x + 1  # call a "thread-unsafe" API here
end
with_adder() do add
    @assert add(0) == 1
    @assert add(1) == 2
end