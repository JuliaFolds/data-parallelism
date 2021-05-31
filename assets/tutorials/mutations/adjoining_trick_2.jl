function withinit(f, semigroup!)
    monoid!(a, b) = semigroup!(a, b)
    monoid!(::Init, b) = semigroup!(f(), b)
    monoid!(a, ::Init) = a
    monoid!(::Init, ::Init) = Init()  # disambiguation
    return monoid!
end

let ⊗ = withinit(() -> [], append!)
    @assert [1] ⊗ [2] == [1, 2]
    @assert [1] ⊗ Init() == [1]
    @assert Init() ⊗ [2] == [2]
    @assert Init() ⊗ Init() == Init()
end

using Folds
ys = Folds.mapreduce(tuple, withinit(() -> Int[], append!), 1:10; init = Init())

@assert ys == 1:10
