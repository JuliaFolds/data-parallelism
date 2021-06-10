# This file was generated, do not modify it. # hide
function slow_square(x)
    sleep(rand(0.01:0.01:0.3))
    return x^2
end

ans = begin # hide
collect(umap(slow_square, 1:10; ntasks = 5))
end # hide
@assert sort(ans) == (1:10) .^ 2 # hide
ans # hide