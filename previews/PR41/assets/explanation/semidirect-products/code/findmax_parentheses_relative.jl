# This file was generated, do not modify it. # hide
shiftindex(n, (d, (i, x))) = (d, (n + i, x))
#                                 ~~~~~
#          shift the index i by the number n of processed elements

function findmax_parentheses_relative(increments)
    singletons = ((1, (x, (1, x))) for x in increments)
    #              |       |
    #              |      the index of the maximum element in a singleton collection
    #             the number of elements in a singleton collection

    monoid = sdpl(+, shiftindex, sdpl(+, shiftvalue, maxpair))
    #             ~  ~.~~~~~~~~  ~~~.~~~~~~~~~~~~~~~~~~~~~~~~
    #             |   |              `-- compute maximum of depths and its index (as above)
    #             |   |
    #             |   `-- 2️⃣ shift the index of right chunk by the size of processed left chunk
    #             |
    #              `-- 1️⃣ compute the size of processed chunk

    return reduce(monoid, singletons)[2][2]
end

ans = begin # hide
findmax_parentheses_relative(increments)
end # hide
@assert ans == (9, 5) # hide
ans # hide