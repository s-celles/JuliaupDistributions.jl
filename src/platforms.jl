"""
Rust target triples for which `juliaup` publishes a version database.

The triple identifies the *`juliaup` client binary*, not the Julia build it
installs. Each client downloads `versiondb-<dbversion>-<target>.json` and
nothing else, so a distribution has to be written into every target a
prospective user might run.

Notably the Linux client is a musl-static binary that also runs on glibc
hosts, which is why both variants exist and carry identical content upstream.
"""
const JULIAUP_TARGETS = ["aarch64-apple-darwin",
                         "aarch64-unknown-linux-gnu",
                         "aarch64-unknown-linux-musl",
                         "i686-pc-windows-gnu",
                         "i686-pc-windows-msvc",
                         "i686-unknown-linux-gnu",
                         "i686-unknown-linux-musl",
                         "x86_64-apple-darwin",
                         "x86_64-pc-windows-gnu",
                         "x86_64-pc-windows-msvc",
                         "x86_64-unknown-freebsd",
                         "x86_64-unknown-linux-gnu",
                         "x86_64-unknown-linux-musl"]

"""
Pointer files naming the database version currently published.

`juliaup` reads exactly one of these depending on the channel it was itself
installed from, so all of them must be written and must agree. Upstream
carries no `DEVPREVIEWCHANNELDBVERSION`, and a client whose pointer file is
missing fails with a 404 on a database the mirror never wrote.
"""
const DBVERSION_FILES = ["DBVERSION",
                         "RELEASECHANNELDBVERSION",
                         "RELEASEPREVIEWCHANNELDBVERSION",
                         "DEVCHANNELDBVERSION"]

"""
Default server `juliaup` downloads from when `JULIAUP_SERVER` is unset.
"""
const DEFAULT_SERVER = "https://julialang-s3.julialang.org"

# Architecture, vendor and operating system as juliaup spells them in a full
# version string, keyed by (os, arch).
const PLATFORM_SUFFIXES =
    Dict((:linux, :x86_64) => "x64.linux.gnu",
         (:linux, :i686) => "x86.linux.gnu",
         (:linux, :aarch64) => "aarch64.linux.gnu",
         (:macos, :x86_64) => "x64.apple.darwin14",
         (:macos, :aarch64) => "aarch64.apple.darwin14",
         (:windows, :x86_64) => "x64.w64.mingw32",
         (:windows, :i686) => "x86.w64.mingw32",
         (:freebsd, :x86_64) => "x64.unknown.freebsd11.1")

# Which client databases a build must be written into. A client lists every
# architecture it can execute, mirroring `compatible_archs` in juliaup: 64 bit
# hosts run 32 bit builds, and Apple Silicon runs x86_64 through Rosetta 2.
const TARGET_MAP =
    Dict((:linux, :x86_64) => ["x86_64-unknown-linux-gnu",
                               "x86_64-unknown-linux-musl"],
         (:linux, :i686) => ["i686-unknown-linux-gnu",
                             "i686-unknown-linux-musl",
                             "x86_64-unknown-linux-gnu",
                             "x86_64-unknown-linux-musl"],
         (:linux, :aarch64) => ["aarch64-unknown-linux-gnu",
                                "aarch64-unknown-linux-musl"],
         (:macos, :x86_64) => ["x86_64-apple-darwin",
                               "aarch64-apple-darwin"],
         (:macos, :aarch64) => ["aarch64-apple-darwin"],
         (:windows, :x86_64) => ["x86_64-pc-windows-gnu",
                                 "x86_64-pc-windows-msvc"],
         (:windows, :i686) => ["i686-pc-windows-gnu",
                               "i686-pc-windows-msvc",
                               "x86_64-pc-windows-gnu",
                               "x86_64-pc-windows-msvc"],
         (:freebsd, :x86_64) => ["x86_64-unknown-freebsd"])

"""
    platform_suffix(os::Symbol, arch::Symbol) -> String

Return the `<arch>.<vendor>.<os>` tail `juliaup` expects in a full version
string, for instance `"x64.linux.gnu"`.
"""
function platform_suffix(os::Symbol, arch::Symbol)
    suffix = get(PLATFORM_SUFFIXES, (os, arch), nothing)

    if isnothing(suffix)
        supported = join(("$o/$a" for (o, a) in
                          sort(collect(keys(PLATFORM_SUFFIXES)))), ", ")
        error("No juliaup platform is defined for $os/$arch. " *
              "Supported combinations are: $supported.")
    end

    return suffix
end

"""
    juliaup_arch(os::Symbol, arch::Symbol) -> String

Architecture token `juliaup` uses in channel aliases and version strings:
`x64`, `x86` or `aarch64`.
"""
function juliaup_arch(os::Symbol, arch::Symbol)
    return String(first(split(platform_suffix(os, arch), '.')))
end

"""
    targets_for(os::Symbol, arch::Symbol) -> Vector{String}

Return the client databases a build for `os`/`arch` must be written into.
"""
function targets_for(os::Symbol, arch::Symbol)
    targets = get(TARGET_MAP, (os, arch), nothing)

    if isnothing(targets)
        supported = join(("$o/$a" for (o, a) in
                          sort(collect(keys(TARGET_MAP)))), ", ")
        error("No juliaup targets are defined for $os/$arch. " *
              "Supported combinations are: $supported.")
    end

    return copy(targets)
end

"""
    target_platform(target::AbstractString) -> Tuple{Symbol, Symbol}

Return the `(os, arch)` a `juliaup` client with this target triple runs
natively.
"""
function target_platform(target::AbstractString)
    arch = startswith(target, "x86_64") ? :x86_64 :
           startswith(target, "i686") ? :i686 :
           startswith(target, "aarch64") ? :aarch64 :
           error("Can not determine the architecture of juliaup target " *
                 "`$target`")

    os = occursin("linux", target) ? :linux :
         occursin("darwin", target) ? :macos :
         occursin("windows", target) ? :windows :
         occursin("freebsd", target) ? :freebsd :
         error("Can not determine the operating system of juliaup target " *
               "`$target`")

    return (os, arch)
end

"""
    sanitize_build_tag(tag::AbstractString) -> String

Replace `.` with `x` in a build tag so it survives `juliaup`'s parsing.

`juliaup` splits the build metadata of a full version string on `.` and reads
the second component as the architecture. A tag carrying dots shifts that
index, and the entry silently resolves to a nonsense architecture. JuliaHub
hit this with early Dyad releases — `1.11.8+dyad-2.1.0-rc3.x64.linux.gnu`
parses its architecture as `"1"` — and their later entries read
`dyad-2x1x0-rc3` instead.
"""
function sanitize_build_tag(tag::AbstractString)
    isempty(tag) && error("The build tag must not be empty")

    sanitized = replace(tag, '.' => 'x')

    if !occursin(r"^[A-Za-z0-9\-]+$", sanitized)
        error("The build tag `$tag` is not a valid semantic version build " *
              "identifier. Only alphanumeric characters, `-` and `.` are " *
              "allowed.")
    end

    return sanitized
end

"""
    full_version_string(julia_version, build_tag, os, arch) -> String

Build the key `juliaup` uses to identify an installable version, for instance
`"1.12.7+myapp-1x2x0.x64.linux.gnu"`. The build tag is sanitized with
[`sanitize_build_tag`](@ref).
"""
function full_version_string(julia_version::VersionNumber,
                             build_tag::AbstractString,
                             os::Symbol,
                             arch::Symbol)
    version = VersionNumber(julia_version.major,
                            julia_version.minor,
                            julia_version.patch)

    return "$version+$(sanitize_build_tag(build_tag))." *
           platform_suffix(os, arch)
end
