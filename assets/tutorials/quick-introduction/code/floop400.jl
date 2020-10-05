# This file was generated, do not modify it. # hide
(imin2, xmin2, imax2, xmax2) =   # hide
let
    imin2 = -1    # -+
    xmin2 = Inf   #  | initializers
    imax2 = -1    #  |
    xmax2 = -Inf  # -+

    for (i, x) in pairs([0, 1, 3, 2])
        if xmin2 > x   # -+
            xmin2 = x  #  | do block bodies
            imin2 = i  #  |
        end            #  |
        if xmax2 < x   #  |
            xmax2 = x  #  |
            imax2 = i  #  |
        end            # -+
    end

    @show imin2 xmin2 imax2 xmax2
    (imin2, xmin2, imax2, xmax2) # hide
end
nothing  # hide