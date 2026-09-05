"""
    install_wrappers(dist::Distribution, destination) -> String

Write the client wrappers into `destination`: `<name>-juliaup` and
`<name>-julia`, plus PowerShell equivalents for Windows.

They export `JULIAUP_SERVER` and `JULIAUP_DEPOT_PATH` before delegating to the
real binaries, so a user's stock `juliaup` installation and its channels are
left alone. This mirrors how the Dyad distribution is shipped.
"""
function install_wrappers(dist::Distribution, destination::AbstractString)
    isempty(dist.server) &&
        error("A `server` must be configured before client wrappers can be " *
              "written, otherwise they point nowhere.")

    mkpath(destination)

    for (filename, contents, executable) in wrapper_scripts(dist)
        path = joinpath(destination, filename)
        write(path, contents)
        executable && Sys.isunix() && chmod(path, 0o755)
    end

    return destination
end

"""
    wrapper_scripts(dist::Distribution)

Return the wrapper scripts as `(filename, contents, executable)` tuples.

Exposed separately from [`install_wrappers`](@ref) so the contents can be
inspected or embedded without touching the filesystem.
"""
function wrapper_scripts(dist::Distribution)
    name = dist.name

    return [("$name-juliaup", shell_wrapper(dist, "juliaup"), true),
            ("$name-julia", shell_wrapper(dist, "julia"), true),
            ("$name-juliaup.ps1", powershell_wrapper(dist, "juliaup"), false),
            ("$name-julia.ps1", powershell_wrapper(dist, "julia"), false)]
end

function shell_wrapper(dist::Distribution, program::AbstractString)
    hint = program == "juliaup" ?
        "is not installed or not on the PATH" :
        "is not installed or not on the PATH. Install it using juliaup"

    return """
    #!/usr/bin/env bash
    # Wrapper around $program for the $(dist.name) distribution.
    #
    # juliaup downloads from whatever host JULIAUP_SERVER points at, so no
    # patched client is needed. The depot is kept separate from the default one
    # so this distribution and a stock Julia installation do not share channels
    # or state.

    command -v $program >/dev/null || {
      echo "$(dist.name)-$program: $program $hint. See https://github.com/JuliaLang/juliaup" >&2
      exit 127
    }

    export JULIAUP_SERVER=$(dist.server)
    export JULIAUP_DEPOT_PATH="\${HOME}/.julia/juliaup-depots/$(dist.depot)"

    exec $program "\$@"
    """
end

function powershell_wrapper(dist::Distribution, program::AbstractString)
    return """
    # Wrapper around $program for the $(dist.name) distribution.
    #
    # The depot is kept separate from the default one so this distribution and
    # a stock Julia installation do not share channels or state.

    if (-not (Get-Command $program -ErrorAction SilentlyContinue)) {
        Write-Error "$(dist.name)-$program: $program is not installed or not on the PATH. See https://github.com/JuliaLang/juliaup"
        exit 127
    }

    \$env:JULIAUP_SERVER = "$(dist.server)"
    \$env:JULIAUP_DEPOT_PATH = Join-Path \$HOME ".julia\\juliaup-depots\\$(dist.depot)"

    & $program @args
    exit \$LASTEXITCODE
    """
end
