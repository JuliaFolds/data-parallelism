odds = append!(odds_left, odds_right)
evens = append!(evens_left, evens_right)

@assert odds == 1:2:10
@assert evens == 2:2:10
