# This file was generated, do not modify it. # hide
(s3, t3) =  # hide
let
    s2 = 0.0  # initializer
    t2 = 0im  # initializer
    for (x, y) in zip(1:3, 1:2:6)
        a = x + y
        b = x - y
        s2 = s2 + a  # converted from `s2 = 0.0 + a` in `@reduce`
        t2 = t2 + b  # converted from `t2 = 0im + b` in `@reduce`
    end      # \
    (s2, t2) #  `- the first arguments are now same as the left hand sides
end