using Folds
using MicroCollections
using BangBang
ys1 = Folds.mapreduce(x -> SingletonVector((x,)), append!!, 1:10)
ys2 = Folds.mapreduce(x -> SingletonSet((x,)), union!!, 1:10)
ys3 = Folds.mapreduce(x -> SingletonDict(x => x^2), merge!!, 1:10)
ys4 = Folds.mapreduce(x -> SingletonDict(isodd(x) => 1), mergewith!!(+), 1:10)
