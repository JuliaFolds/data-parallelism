using Folds

xs = 1:2:100
ys = similar(xs)  # output
Folds.map!(x -> gcd(42, x), ys, xs)
