# This file was generated, do not modify it. # hide
using OnlineStats
using Folds
ans = begin # hide
Folds.reduce(Mean(), 1:10)
end # hide
@assert ans == fit!(Mean(), 1:10)  # hide
ans # hide