# Data-parallel programming in Julia

\note{
If you are new to parallel programming, start from
[A quick introduction to data parallelism in Julia](tutorials/quick-introduction).
}

## Table of contents

```julia:globaltoc
#hideall

let root = @__DIR__
    chapters = [
        "tutorials" => "Tutorials",
        "howto" => "How-to guides",
        "reference" => "References",
        "explanation" => "Explanation",
    ]
    firsts = Dict(
        "tutorials" => [
            "quick-introduction.md",
            "mutation.md",
        ],
    )
    external = Dict(
        "tutorials" => [
            "[Transducers.jl / Parallel processing tutorial](https://juliafolds.github.io/Transducers.jl/stable/tutorials/tutorial_parallel/)",
            "[Transducers.jl / Splitting a string into words and counting them in parallel](https://juliafolds.github.io/Transducers.jl/stable/tutorials/words/)",
            "[FLoops.jl / Parallel loops](https://juliafolds.github.io/FLoops.jl/stable/tutorials/parallel/)",
            "[FoldsCUDA.jl / Examples](https://juliafolds.github.io/FoldsCUDA.jl/dev/)",
        ],
        "howto" => [
            "[FLoops.jl / How to write X in parallel](https://juliafolds.github.io/FLoops.jl/stable/howto/parallel/)",
        ],
        "reference" => [
            "[FLoops.jl documentation](https://juliafolds.github.io/FLoops.jl/stable/)",
            "[Folds.jl documentation](https://juliafolds.github.io/Folds.jl/stable/)",
            "[ThreadsX.jl documentation](https://tkf.github.io/ThreadsX.jl/dev/)",
            "[Transducers.jl documentation](https://juliafolds.github.io/Transducers.jl/stable/)",
            "[See JuliaFolds organization for more packages](https://github.com/JuliaFolds)",
        ],
    )

    title(path) = open(title, path)
    function title(io::IO)
        for ln in eachline(io)
            m = match(r"^# +(.*)", ln)
            if m !== nothing
                return m[1]
            end
        end
    end

    for (cdir, ctitle) in chapters
        files = readdir(joinpath(root, cdir))
        files = filter(endswith(".md"), files)
        if (files0 = get(firsts, cdir, nothing)) !== nothing
            files = vcat(
                intersect(files0, files),
                setdiff(files, files0),
            )
        end
        pages = Iterators.map(files) do path
            t = title(joinpath(root, cdir, path))
            if t === nothing
                return nothing
            else
                stem = splitext(basename(path))[1]
                return "[$t]($cdir/$stem/)"
            end
        end
        pages = collect(Iterators.filter(!isnothing, pages))
        append!(pages, map(x -> "🔗 $x", get(external, cdir, [])))

        println("* $ctitle")
        for link in pages
            println("  * ", link)
        end
    end
end
```

\textoutput{globaltoc}
