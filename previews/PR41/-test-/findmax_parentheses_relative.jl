# This file was generated, do not modify it. # hide
#hideall

# ...which does not mean we shouldn't be unit-testing it
    using Test
    @testset begin
        ⊗ = sdpl(+, shiftindex, sdpl(+, shiftvalue, maxpair))
        prod3(xs) = Iterators.product(xs, xs, xs)
        nfailed = 0
        for (n1, n2, n3) in prod3(1:3),
                (d1, d2, d3) in prod3(1:3),
                (i1, i2, i3) in prod3('a':'c'),
                (m1, m2, m3) in prod3(1:3)
            x1 = (n1, (d1, (i1, m1)))
            x2 = (n2, (d2, (i2, m2)))
            x3 = (n3, (d3, (i3, m3)))
            nfailed += !(x1 ⊗ (x2 ⊗ x3) == (x1 ⊗ x2) ⊗ x3)
        end
        @test nfailed == 0
    end

Base.Text("OK")