xs = 1:2:100
ys = similar(xs)  # output
Threads.@threads for i in eachindex(xs, ys)
    @inbounds ys[i] = gcd(42, xs[i])
end
