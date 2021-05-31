odds_left, evens_left = basecase(chunk_left)
odds_right, evens_right = basecase(chunk_right)

@assert odds_left == 1:2:5
@assert evens_left == 2:2:5
@assert odds_right == 7:2:10
@assert evens_right == 6:2:10
