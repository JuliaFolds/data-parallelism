<!--
Add here global page variables to use throughout your
website.
The website_* must be defined for the RSS to work
-->
@def website_title = "A guide to data parallelism in Julia"
@def website_descr = "A guide to data parallelism in Julia"
@def website_url   = get(ENV, "JULIA_FRANKLIN_WEBSITE_URL", "https://juliafolds.github.io/data-parallelism")

@def prepath = get(ENV, "JULIA_FRANKLIN_PREPATH", "data-parallelism")

@def author = "Takafumi Arakaki"

@def mintoclevel = 2

<!--
Add here files or directories that should be ignored by Franklin, otherwise
these files might be copied and, if markdown, processed by Franklin which
you might not want. Indicate directories by ending the name with a `/`.
-->
@def ignore = ["node_modules/", "franklin", "franklin.pub"]

<!--
Add here global latex commands to use throughout your
pages. It can be math commands but does not need to be.
For instance:
* \newcommand{\phrase}{This is a long phrase to copy.}
-->
\newcommand{\R}{\mathbb R}
\newcommand{\scal}[1]{\langle #1 \rangle}

\newcommand{\kbd}[1]{~~~<kbd>!#1</kbd>~~~}

\newcommand{\note}[1]{@@note @@title 💡 Note@@ @@content #1 @@ @@}
\newcommand{\warn}[1]{@@warn @@title ⚠ Warning@@ @@content #1 @@ @@}

<!--
Test case command. See ./utils.jl for implementation.

Arguments:
1. Test name.
2. Test code. It must throw in a failure case.
-->
\newcommand{\test}[2]{
```julia:/-test-/!#1
#hideall

!#2

Base.Text("OK")
```

\testcode{!#2}
\testcheck{!#1}
}
