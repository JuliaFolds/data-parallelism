module TestMutations

using Test

module Example
S1 = include("example_1.jl")
S2 = include("example_2.jl")
include("example_3.jl")
S3 = S
S = nothing
include("example_4.jl")
S4 = S
S = nothing
include("example_5.jl")
S5 = S
end # module Example

@testset "Example" begin
    @test Example.S2 ≈ Example.S1
    @test Example.S3 ≈ Example.S1
    @test Example.S4 ≈ Example.S1
    @test Example.S5 ≈ Example.S1
end

module Filling
include("filling_1.jl")
ys1 = ys
ys = nothing
include("filling_2.jl")
ys2 = ys
ys = nothing
ys3 = include("filling_3.jl")
end

@testset "Filling" begin
    @test Filling.ys1 == gcd.(42, 1:2:100)
    @test Filling.ys2 == gcd.(42, 1:2:100)
    @test Filling.ys3 == gcd.(42, 1:2:100)
end

module FLoopsReduce
using Test: @test as @assert
include("floops_reduce_1.jl")
include("floops_reduce_2.jl")
include("floops_reduce_3.jl")
include("floops_reduce_4.jl")
include("floops_reduce_5.jl")
end

module FLoopsReduce6
include("floops_reduce_6_vcat.jl")
end

@testset "floops_reduce_6_vcat.jl" begin
    @test FLoopsReduce6.odds == 1:2:10
    @test FLoopsReduce6.evens == 2:2:10
end

module FLoopsReduceDo
using Test: @test as @assert
using FLoops
include("floops_reduce_do_1.jl")
include("floops_reduce_do_2.jl")
include("floops_reduce_do_3.jl")
include("floops_reduce_do_4.jl")
end

module FLoopsReduceDoOnlineStats
using Test: @test as @assert
include("floops_reduce_do_os_1.jl")
acc = nothing
include("floops_reduce_do_os_2.jl")
end

module FLoopsReduceDo2
using Test: @test as @assert
using FLoops
include("floops_reduce_do_incorrect.jl")
include("floops_reduce_do_correct.jl")
end

module OwnershipPassingStyleSecond1
include("ownership_passing_style_second_1_intro.jl")
end

module OwnershipPassingStyleSecond2
using Test: @test as @assert
using FLoops
include("ownership_passing_style_second_2_wrong.jl")
end

module OwnershipPassingStyleSecond3
using Test: @test as @assert
using FLoops
include("ownership_passing_style_second_3_correct.jl")
end

module TransducersOnInit
using Test: @test as @assert
include("transducers_oninit.jl")
end

module CombiningContainers1
using Test: @test as @assert
include("combining_containers_1.jl")
end

module CombiningContainers2
include("combining_containers_2.jl")
end

module CombiningContainers3
include("combining_containers_3.jl")
end

@testset "CombiningContainers" begin
    @test CombiningContainers2.ys1 == CombiningContainers1.ys1
    @test CombiningContainers2.ys2 == CombiningContainers1.ys2
    @test CombiningContainers2.ys3 == CombiningContainers1.ys3
    @test CombiningContainers2.ys4 == CombiningContainers1.ys4
    @test CombiningContainers3.ys1 == CombiningContainers1.ys1
    @test CombiningContainers3.ys2 == CombiningContainers1.ys2
    @test CombiningContainers3.ys3 == CombiningContainers1.ys3
end

module AccidentalMutations
include("accidental_mutations_1_threads.jl")
include("accidental_mutations_2_seq.jl")
include("accidental_mutations_3_threads_fixed.jl")
include("accidental_mutations_4_floop.jl")
include("accidental_mutations_5_floop_fixed.jl")
end

@testset "AccidentalMutations" begin
    @test AccidentalMutations.f() isa Any
    @test AccidentalMutations.f_fixed() == AccidentalMutations.f_seq()
    @test AccidentalMutations.f_floop_fixed() == AccidentalMutations.f_seq()

    local err
    @test (err = try
        AccidentalMutations.f_floop()
        nothing
    catch err_
        err_
    end) isa Exception
    @test occursin("has 1 boxed variable", sprint(showerror, err))
end

module FLoopsInit
using Test: @test as @assert
include("floops_init_1.jl")
end

module AdjoiningTrick
using Test: @test as @assert
include("adjoining_trick_1.jl")
include("adjoining_trick_2.jl")
end

end  # module
