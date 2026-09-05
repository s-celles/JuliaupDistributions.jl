"""
    Distribution(; channel, julia_version, build_tag, kwargs...)

Description of a Julia distribution published through `juliaup`.

Users install it by pointing `JULIAUP_SERVER` at `server` and running
`juliaup add <channel>`. The wrappers produced by [`install_wrappers`](@ref)
set that variable for them and isolate the depot so a stock `juliaup`
installation is left untouched.

# Keyword Arguments
- `channel`: Channel name users pass to `juliaup add`, e.g. `"myapp-1.2.0"`
- `julia_version`: Julia version the distribution is built on
- `build_tag`: Build identifier embedded in the full version string; sanitized
  with [`sanitize_build_tag`](@ref)
- `name`: Application name, used to derive asset filenames and wrapper names
- `version`: Application version, used to derive asset filenames
- `server`: HTTPS base url the database is published under
- `asset_base`: Base path or url the tarballs are served from. A relative value
  keeps the database portable across hosts, an absolute url points elsewhere
- `mirror = true`: Merge the upstream database in so stock channels keep working
- `dbversion = nothing`: Database version to publish; resolved above upstream at
  publish time when left unset
- `depot`: Directory under `~/.julia/juliaup-depots` the wrappers isolate the
  installation into; defaults to the server host
- `upstream_server = DEFAULT_SERVER`: Server to mirror from
"""
struct Distribution
    channel::String
    julia_version::VersionNumber
    build_tag::String
    name::String
    version::String
    server::String
    asset_base::String
    mirror::Bool
    dbversion::Union{VersionNumber, Nothing}
    depot::String
    upstream_server::String
end

function Distribution(; channel::AbstractString,
                      julia_version::VersionNumber,
                      build_tag::AbstractString,
                      name::AbstractString,
                      version::AbstractString,
                      server::AbstractString = "",
                      asset_base::AbstractString = "assets",
                      mirror::Bool = true,
                      dbversion::Union{VersionNumber, Nothing} = nothing,
                      depot::AbstractString = default_depot(server),
                      upstream_server::AbstractString = DEFAULT_SERVER)
    validate_server(server)
    sanitize_build_tag(build_tag) # fail here, not on every user's machine

    return Distribution(channel, julia_version, build_tag, name, version,
                        server, asset_base, mirror, dbversion, depot,
                        upstream_server)
end

"""
    Distribution(project::AbstractString; kwargs...)

Build a distribution from a Julia project directory, taking `name` and
`version` from its `Project.toml`. Everything else is passed through.
"""
function Distribution(project::AbstractString; kwargs...)
    manifest = TOML.parsefile(joinpath(project, "Project.toml"))

    name = lowercase(get(manifest, "name", "app"))
    version = get(manifest, "version", "0.0.1")

    defaults = (; channel = "$name-$version",
                build_tag = "$name-$version",
                julia_version = project_julia_version(project))

    return Distribution(; defaults..., name, version, kwargs...)
end

"""
    project_julia_version(project::AbstractString) -> VersionNumber

Read the Julia version a project's `Manifest.toml` was resolved with, falling
back to the running version.
"""
function project_julia_version(project::AbstractString)
    return try
        VersionNumber(TOML.parsefile(joinpath(project,
                                              "Manifest.toml"))["julia_version"])
    catch
        VERSION
    end
end

"""
    validate_server(server::AbstractString)

Reject a server url `juliaup` would refuse. It requires HTTPS except on
loopback, and rather than let every user discover that, fail while publishing.
"""
function validate_server(server::AbstractString)
    isempty(server) && return

    scheme, rest = if startswith(server, "https://")
        ("https", server[9:end])
    elseif startswith(server, "http://")
        ("http", server[8:end])
    else
        error("The juliaup server `$server` must be an http(s) url")
    end

    host = first(split(first(split(rest, '/')), ':'))

    if scheme == "http" &&
       !(host in ["localhost", "127.0.0.1", "::1", "[::1]"])
        error("juliaup refuses a plain HTTP server unless it is loopback. " *
              "Publish `$server` over HTTPS instead.")
    end

    return
end

"""
    default_depot(server::AbstractString) -> String

Directory name under `~/.julia/juliaup-depots` to isolate a distribution into,
derived from the server host so distributions from different vendors do not
collide.
"""
function default_depot(server::AbstractString)
    isempty(server) && return "juliaup-distribution"

    rest = replace(server, r"^https?://" => "")
    host = first(split(first(split(rest, '/')), ':'))

    return isempty(host) ? "juliaup-distribution" : String(host)
end

"""
    asset_url(dist::Distribution, os::Symbol, arch::Symbol) -> String

Url of the tarball for one platform, following the convention
`<name>-<version>-<os>-<arch>.tar.gz`.
"""
function asset_url(dist::Distribution, os::Symbol, arch::Symbol)
    filename = "$(dist.name)-$(dist.version)-$os-$arch.tar.gz"

    return isempty(dist.asset_base) ? filename :
           rstrip(dist.asset_base, '/') * "/" * filename
end

"""
    publish(dist::Distribution, site; assets, upstream = nothing, dbversion)

Write the static file tree a `juliaup` client reads into `site`.

`assets` lists the platforms that were built, either as `(os, arch)` tuples —
whose tarball urls are then derived from `dist.asset_base` — or as
`(os, arch) => url` pairs when the urls are known.

The resulting tree can be served by any static host:

```
<site>/juliaup/DBVERSION
<site>/juliaup/RELEASECHANNELDBVERSION
<site>/juliaup/RELEASEPREVIEWCHANNELDBVERSION
<site>/juliaup/DEVCHANNELDBVERSION
<site>/juliaup/versiondb/versiondb-<dbversion>-<target>.json
```

All four pointer files carry the same number. `juliaup` reads only the one
matching the channel it was installed from, and a client on `dev` or
`releasepreview` would otherwise take a 404 on a database never written.
"""
function publish(dist::Distribution, site::AbstractString;
                 assets,
                 upstream::Union{Dict{String, VersionDB}, Nothing} = nothing,
                 dbversion::Union{VersionNumber, Nothing} = dist.dbversion)
    platforms = normalize_assets(dist, assets)

    isempty(platforms) &&
        error("No assets were given to publish. Pass at least one (os, arch).")

    if isnothing(upstream) && dist.mirror
        upstream = fetch_upstream(; server = dist.upstream_server)
    end

    if isnothing(dbversion)
        upstream_version = isnothing(upstream) ?
            fetch_dbversion(; server = dist.upstream_server) :
            maximum(db.dbversion for db in values(upstream))

        dbversion = next_dbversion(upstream_version,
                                   published_dbversion(site, upstream_version))
    end

    juliaup_dir = joinpath(site, "juliaup")
    mkpath(joinpath(juliaup_dir, "versiondb"))

    for target in JULIAUP_TARGETS
        base = isnothing(upstream) ? VersionDB(dbversion) :
               copy(upstream[target])

        db = VersionDB(base.versions, base.channels, dbversion)

        register!(db, dist, target, platforms)

        write_versiondb(joinpath(juliaup_dir, "versiondb",
                                 "versiondb-$dbversion-$target.json"), db)
    end

    for name in DBVERSION_FILES
        write(joinpath(juliaup_dir, name), "$dbversion\n")
    end

    @info "Published juliaup channel `$(dist.channel)` at database " *
          "version $dbversion into $site"

    return dbversion
end

function normalize_assets(dist::Distribution, assets)
    platforms = Pair{Tuple{Symbol, Symbol}, String}[]

    for entry in assets
        if entry isa Pair
            os, arch = entry.first
            push!(platforms, (os, arch) => String(entry.second))
        else
            os, arch = entry
            push!(platforms, (os, arch) => asset_url(dist, os, arch))
        end
    end

    return platforms
end

"""
    register!(db, dist, target, platforms) -> VersionDB

Add the distribution's versions and channels to one target's database.

Every platform the target can execute is registered under a `<channel>~<arch>`
alias, following the convention upstream uses. The bare channel resolves to the
target's native architecture when it was built, and otherwise to the first
compatible build — which is how an Apple Silicon client falls back to an
x86_64 distribution through Rosetta 2.
"""
function register!(db::VersionDB, dist::Distribution,
                   target::AbstractString, platforms)
    compatible = [platform for platform in platforms
                  if target in targets_for(platform.first...)]

    isempty(compatible) && return db

    native = target_platform(target)
    preferred = something(findfirst(p -> p.first == native, compatible), 1)

    for (index, ((os, arch), url)) in enumerate(compatible)
        fullversion = full_version_string(dist.julia_version,
                                          dist.build_tag, os, arch)

        add_version!(db, fullversion, url)
        add_channel!(db, "$(dist.channel)~$(juliaup_arch(os, arch))",
                     fullversion)

        index == preferred && add_channel!(db, dist.channel, fullversion)
    end

    return db
end

"""
    published_dbversion(site, fallback) -> VersionNumber

Read back the database version a site already advertises, so republishing keeps
climbing rather than reusing a number clients have already cached.
"""
function published_dbversion(site::AbstractString, fallback::VersionNumber)
    path = joinpath(site, "juliaup", "RELEASECHANNELDBVERSION")

    isfile(path) || return fallback

    return try
        VersionNumber(strip(read(path, String)))
    catch
        fallback
    end
end
