using Folds
using Transducers: OnInit
ys = Folds.mapreduce(x -> (x, 2x, 3x), .+, 1:10; init = OnInit(() -> [0, 0, 0]))

@assert ys == [sum(1:10), 2sum(1:10), 3sum(1:10)]
