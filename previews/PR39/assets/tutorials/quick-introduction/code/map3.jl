# This file was generated, do not modify it. # hide
using Distributed
a3 = pmap(string, 1:9, 'a':'i')
@assert a1 == a3