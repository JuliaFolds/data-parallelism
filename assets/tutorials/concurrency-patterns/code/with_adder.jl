# This file was generated, do not modify it. # hide
with_adder = define_service() do x
    return x + 1
end
with_adder() do add
    @assert add(0) == 1
    @assert add(1) == 2
end