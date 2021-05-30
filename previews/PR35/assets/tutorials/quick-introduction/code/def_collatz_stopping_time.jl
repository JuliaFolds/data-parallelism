# This file was generated, do not modify it. # hide
function collatz_stopping_time(x)
    n = 0
    while true
        x == 1 && return n
        n += 1
        x = collatz(x)
    end
end