# This file was generated, do not modify it. # hide
str = "dbkgbjkahbidcbcfhfdeedhkggdigfecefjiakccjhghjcgefd"
f1 = mapreduce(x -> Dict(x => 1), mergewith!(+), str)