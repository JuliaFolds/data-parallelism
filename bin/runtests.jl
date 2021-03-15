#!/bin/bash
# -*- mode: julia -*-
#=
JULIA="${JULIA:-julia --color=yes --startup-file=no}"
export JULIA_PROJECT="$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
export JULIA_NUM_THREADS=4
export DISPLAY=
export GKSwstype=nul
exec ${JULIA} "${BASH_SOURCE[0]}" "$@"
=#
module TestDataParallelism

using Test
using Glob

@testset "$(basename(file))" for file in sort(
    readdir(glob"*/*/test_*.jl", joinpath(@__DIR__, "../src/_assets/")),
)
    include(file)
end

end # module TestDataParallelism
