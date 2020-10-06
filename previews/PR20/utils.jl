const TEST_RESULT_PATH = joinpath(@__DIR__, ".test-result")
write(TEST_RESULT_PATH, "")

function lx_testcode(com, _)
    code = Franklin.content(com.braces[1])
    return """
    @@test_code
    @@title 🔬 Test Code@@
    ```julia
    $code
    ```
    @@
    """
end

function lx_testcheck(com, _)
    testname = Franklin.content(com.braces[1])
    respath = joinpath(@__DIR__, "__site", "-test-", "output", testname * ".res")
    outpath = joinpath(@__DIR__, "__site", "-test-", "output", testname * ".out")
    result = read(respath, String)
    ok = result == "OK"
    if !ok
        @error(
            "Test `$testname` failed!",
            result = Text(result),
            output = Text(read(outpath, String))
        )
        write(TEST_RESULT_PATH, "failed")
    end
    if ok
        return """
        @@test_ok
        @@title  ☑ Pass@@
        \\output{/-test-/$testname}
        @@
        """
    else
        return """
        @@test_failure
        @@title  ⚠ Failure@@
        \\show{/-test-/$testname}
        @@
        """
    end
end
