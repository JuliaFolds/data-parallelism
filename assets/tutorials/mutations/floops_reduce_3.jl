chunk_left = 1:5
chunk_right = 6:10
@assert vcat(chunk_left, chunk_right) == 1:10  # original input
