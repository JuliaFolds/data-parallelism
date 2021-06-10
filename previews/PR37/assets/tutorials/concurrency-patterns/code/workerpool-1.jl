# This file was generated, do not modify it. # hide
using Base.Threads: @spawn

function workerpool(work!, allocate, request; ntasks = Threads.nthreads())
    @sync for _ in 1:ntasks
        @spawn allocate() do resource
            for input in request
                work!(input, resource)
            end
        end
    end
end