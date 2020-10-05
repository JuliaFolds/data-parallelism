# This file was generated, do not modify it. # hide
b1 = map(x -> x + 1, 1:3)
b2 = [x + 1 for x in 1:3]         # array comprehension
b3 = collect(x + 1 for x in 1:3)  # iterator comprehension
@assert b1 == b2 == b3
b1