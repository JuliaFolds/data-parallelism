# This file was generated, do not modify it. # hide
maxpair((i, x), (j, y)) = y > x ? (j, y) : (i, x)
shiftvalue(d, (i, x)) = (i, d + x)

function findmax_parentheses(increments)
    singletons = ((x, (i, x)) for (i, x) in pairs(increments))
    monoid = sdpl(+, shiftvalue, maxpair)
    return reduce(monoid, singletons)[2]
end

ans = begin # hide
findmax_parentheses(increments)
end # hide
@assert ans == (9, 5) # hide
ans # hide