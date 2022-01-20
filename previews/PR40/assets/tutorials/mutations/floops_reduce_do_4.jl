ys_left .+= ys_right
ys = ys_left

@assert ys == mapreduce(n -> [n, 2n, 3n], .+, 1:10)
