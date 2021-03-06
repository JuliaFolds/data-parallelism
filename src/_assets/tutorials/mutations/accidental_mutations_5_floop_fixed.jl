using FLoops

function f_floop_fixed(n = 2^10)
    ys = zeros(Int, n)
    @floop ThreadedEx() for i in 1:n
        local y = gcd(42, i)
        some_function()
        ys[i] = y
    end

    if ys[1] > 0
        y = 1
    end

    return ys
end
