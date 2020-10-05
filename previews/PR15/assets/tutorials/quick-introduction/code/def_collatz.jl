# This file was generated, do not modify it. # hide
collatz(x) =
    if iseven(x)
        x ÷ 2
    else
        3x + 1
    end