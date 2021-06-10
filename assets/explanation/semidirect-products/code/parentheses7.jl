# This file was generated, do not modify it. # hide
ans = begin # hide
mapreduce(x -> (x, x), ⊗, increments)
end # hide
@assert ans[2] == maximum(depths) # hide
ans # hide