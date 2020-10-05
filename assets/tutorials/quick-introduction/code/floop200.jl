# This file was generated, do not modify it. # hide
@floop for (x, y) in zip(1:3, 1:2:6)
    a = x + y
    b = x - y
    @reduce(s2 = 0.0 + a, t2 = 0im + b)
end
(s2, t2)