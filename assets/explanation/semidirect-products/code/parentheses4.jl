# This file was generated, do not modify it. # hide
function ⊗((d1, m1), (d2, m2))
    d = d1 + d2           # total change in depth

    m2′ = d1 + m2         # shifting the maximum of the right chunk before comparison
    m = max(m1, m2′)      # find the maximum

    return (d, m)
end