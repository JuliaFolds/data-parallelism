# This file was generated, do not modify it. # hide
parentheses = collect("(((())((()))) ((())))")
increments = ifelse.(parentheses .== '(', +1, ifelse.(parentheses .== ')', -1, 0))
depths = cumsum(increments)
maximum(depths)