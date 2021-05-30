N = 40
M = 1000
As = [randn(N, N) for _ in 1:M]
Bs = [randn(N, N) for _ in 1:M]
sum(A * B for (A, B) in zip(As, Bs))
