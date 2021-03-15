struct Init end

function asmonoid(semigroup)
    monoid(a, b) = semigroup(a, b)
    monoid(::Init, b) = b
    monoid(a, ::Init) = a
    monoid(::Init, ::Init) = Init()  # disambiguation
    return monoid
end

let ⊗ = asmonoid(min)
    @assert 1 ⊗ 2 == 1
    @assert 1 ⊗ Init() == 1
    @assert Init() ⊗ 2 == 2
    @assert Init() ⊗ Init() == Init()
end
