# This file was generated, do not modify it. # hide
# Prepare inputs to the worker pool
results = Vector{Float64}(undef, 2^5)
works = Channel{typeof(Ref(results, 1))}(Inf)
for i in eachindex(results)
    put!(works, Ref(results, i))
end
close(works)

let buffer_length = 2^10

    # `allocate(body)` function allocates the resource and pass it to `body`:
    function allocate(body)
        open("/dev/urandom") do file
            buffer = Vector{UInt8}(undef, buffer_length)
            body((file, buffer))
        end
    end

    # The first argument to `workerpool` is a function that takes a work and a
    # resource:
    workerpool(allocate, works) do ref, (file, buffer)
        read!(file, buffer)
        ref[] = sum(buffer; init = 0.0)
    end

    sum(results) / (length(results) * buffer_length)
end