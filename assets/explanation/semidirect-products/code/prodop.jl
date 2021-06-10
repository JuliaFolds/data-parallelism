# This file was generated, do not modify it. # hide
prodop(⊗₁, ⊗₂) = ((xa, xb), (ya, yb)) -> (xa ⊗₁ ya, xb ⊗₂ yb)

ans = begin # hide
mapreduce(x -> (x, x), prodop(+, *), 1:10; init = (0, 1))  # example
end # hide
ans == (sum(1:10), prod(1:10)) # hide
ans # hide