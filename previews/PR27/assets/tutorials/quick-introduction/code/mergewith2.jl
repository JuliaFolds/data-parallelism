# This file was generated, do not modify it. # hide
using BangBang: mergewith!!
using MicroCollections: SingletonDict

f2 = ThreadsX.mapreduce(x -> SingletonDict(x => 1), mergewith!!(+), str)
@assert f1 == f2