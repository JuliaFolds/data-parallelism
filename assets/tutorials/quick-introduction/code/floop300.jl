# This file was generated, do not modify it. # hide
@floop for (i, x) in pairs([0, 1, 3, 2])
    @reduce() do (imin = -1; i), (xmin = Inf; x)
        if xmin > x
            xmin = x
            imin = i
        end
    end
    @reduce() do (imax = -1; i), (xmax = -Inf; x)
        if xmax < x
            xmax = x
            imax = i
        end
    end
end

@show imin xmin imax xmax