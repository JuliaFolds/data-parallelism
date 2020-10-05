# This file was generated, do not modify it. # hide
hist1 = collatz_histogram(1:1_000_000, SequentialEx())
hist2 = collatz_histogram(1:1_000_000, ThreadedEx())
@assert hist1 == hist2