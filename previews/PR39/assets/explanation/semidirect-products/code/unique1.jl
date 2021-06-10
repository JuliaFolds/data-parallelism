# This file was generated, do not modify it. # hide
function vector_unique(xs)
    singletons = ((Set([x]), [x]) for x in xs)
    monoid = sdpl(union, (a, b) -> setdiff(b, a), vcat)
    return last(reduce(monoid, singletons))
end