# This file was generated, do not modify it. # hide
using ThreadsX
a2 = ThreadsX.map(string, 1:9, 'a':'i')
@assert a1 == a2