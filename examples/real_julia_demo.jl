# Registers a real Julia release under a channel name of our own, then installs it with juliaup.
#
# This is the honest end of the spectrum: no stub tarball, no mock server. It takes the actual
# release entry from the public database, republishes it under a made-up channel, and lets a real
# `juliaup` download and install the real Julia from julialang.org.
#
#     julia --project=. examples/real_julia_demo.jl
#
# It downloads a full Julia (a few hundred megabytes) into a temporary depot, and removes it again
# unless KEEP=1 is set.

using JuliaupDistributions
using JuliaupDistributions: fetch_dbversion, fetch_versiondb, read_versiondb,
                            write_versiondb, VersionDB, add_version!,
                            add_channel!, DEFAULT_SERVER, DBVERSION_FILES

"""
The target triple of the local juliaup binary, i.e. the one database it reads.

Derived from the name juliaup gave its own cached copy rather than guessed from the host: the
Linux client is musl-static and reads the musl database even on a glibc system.
"""
function juliaup_target(home = joinpath(homedir(), ".julia", "juliaup"))
    for entry in readdir(home)
        captured = match(r"^versiondb-(.+)\.json$", entry)
        isnothing(captured) || return captured[1]
    end

    error("Could not determine the local juliaup target triple from $home. " *
          "Run `juliaup status` once so it writes its database.")
end

isnothing(Sys.which("juliaup")) &&
    error("This demo needs `juliaup` on the PATH.")

target = juliaup_target()
channel = "demo-julia"

@info "Reading the public database" target

upstream_version = fetch_dbversion()
upstream = fetch_versiondb(target; dbversion = upstream_version)

# The real release entry, exactly as julialang.org publishes it.
release = upstream.channels["release"]
urlpath = upstream.versions[release]

# UrlPath is relative to the server base. Our database is served from somewhere else, so the
# reference has to become absolute — which is the same mechanism that lets a database on GitHub
# Pages point at tarballs on a releases page.
absolute = rstrip(DEFAULT_SERVER, '/') * "/" * urlpath

@info "Republishing it under our own channel" release absolute channel

# A database carrying one entry: the real Julia, under a name of our choosing. The version number
# has to exceed both the number built into the juliaup binary and its local copy, otherwise juliaup
# ignores the file and says nothing at all.
db = VersionDB(v"99.0.0")
add_version!(db, release, absolute)
add_channel!(db, channel, release)

depot = mktempdir()
home = joinpath(depot, "juliaup")
mkpath(home)

# juliaup reads its database straight out of the depot, so it can be placed there directly. No
# server, no Pages deploy — which is what makes this practical to run before publishing anything.
write_versiondb(joinpath(home, "versiondb-$target.json"), db)

for name in DBVERSION_FILES
    write(joinpath(home, name), "99.0.0\n")
end

env = copy(ENV)
env["JULIAUP_DEPOT_PATH"] = depot

try
    @info "Installing with juliaup" channel
    run(setenv(`juliaup add $channel`, env))

    println("\n--- juliaup status ---")
    run(setenv(`juliaup status`, env))

    println("\n--- running the installed Julia ---")
    run(setenv(`julia +$channel --startup-file=no -e
                'println("Julia ", VERSION, " installed as the $(ARGS[1]) channel")' $channel`,
               env))

    installed = joinpath(home, "julia-$release")
    isdir(installed) ||
        error("juliaup reported success but $installed is missing")

    println("\nInstalled from $absolute")
    println("into $installed")
finally
    if get(ENV, "KEEP", "0") == "1"
        @info "Keeping the depot" depot
    else
        rm(depot; recursive = true, force = true)
    end
end
