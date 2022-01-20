using Folds
ys1 = Folds.collect(1:10)
ys2 = Folds.set(1:10)
ys3 = Folds.dict(x => x^2 for x in 1:10)
