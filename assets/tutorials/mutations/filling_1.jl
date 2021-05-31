using FLoops

xs = 1:2:100
ys = similar(xs)  # output
@floop ThreadedEx() for (i, x) in pairs(xs)
    @inbounds ys[i] = gcd(42, x)
end
