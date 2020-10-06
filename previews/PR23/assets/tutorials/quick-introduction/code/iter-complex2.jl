# This file was generated, do not modify it. # hide
using Transducers
c2 = dcollect(y for x in 1:3 if isodd(x) for y in 1:x)
@assert c1 == c2