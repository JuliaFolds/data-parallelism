using Folds
using Transducers: OnInit
ys1 = Folds.mapreduce(x -> [x], append!, 1:10; init = OnInit(() -> Int[]))
ys2 = Folds.mapreduce(x -> Set([x]), union!, 1:10; init = OnInit(Set{Int}))
ys3 = Folds.mapreduce(x -> Dict(x => x^2), merge!, 1:10; init = OnInit(Dict{Int,Int}))
ys4 = Folds.mapreduce(x -> Dict(isodd(x) => 1), mergewith!(+), 1:10; init = OnInit(Dict{Bool,Int}))

@assert ys1 == 1:10
@assert ys2 == Set(1:10)
@assert ys3 == Dict(x => x^2 for x in 1:10)
@assert ys4 == Dict(false => 5, true => 5)
