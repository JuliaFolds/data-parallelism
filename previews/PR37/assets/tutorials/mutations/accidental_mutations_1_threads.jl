function f(n = 2^10)
    ys = zeros(Int, n)
    Threads.@threads for i in 1:n
        y = gcd(42, i)
        some_function()
        ys[i] = y
    end

    # Suppose that some unrelated code uses the same variable names as the
    # temporary variables in the parallel loop:
    if ys[1] > 0
        y = 1
    end

    return ys
end

# Some function that Julia does not inline:
@noinline some_function() = _FALSE_[] && error("unreachable")
const _FALSE_ = Ref(false)
