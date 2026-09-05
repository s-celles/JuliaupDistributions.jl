"""
    VersionDB(versions, channels, dbversion)

In-memory form of a `juliaup` version database.

- `versions` maps a full version string such as `"1.12.7+0.x64.linux.gnu"` to
  the `UrlPath` of the distribution tarball. The path is resolved against the
  server base, so a relative value keeps the database portable across hosts
  while an absolute URL points at another host entirely.
- `channels` maps a channel name such as `"release"` to a key of `versions`.
- `dbversion` is the number published in the `*DBVERSION` pointer files.
"""
struct VersionDB
    versions::Dict{String, String}
    channels::Dict{String, String}
    dbversion::VersionNumber
end

function VersionDB(dbversion::VersionNumber)
    return VersionDB(Dict{String, String}(),
                     Dict{String, String}(),
                     dbversion)
end

function Base.copy(db::VersionDB)
    return VersionDB(copy(db.versions), copy(db.channels), db.dbversion)
end

"""
    read_versiondb(path::AbstractString) -> VersionDB

Parse a `juliaup` version database. The nested JSON objects are flattened into
plain `Dict`s so the representation does not depend on the JSON implementation.
"""
function read_versiondb(path::AbstractString)
    parsed = JSON.parsefile(path)

    versions = Dict{String, String}(
        key => value["UrlPath"]
        for (key, value) in parsed["AvailableVersions"])

    channels = Dict{String, String}(
        key => value["Version"]
        for (key, value) in parsed["AvailableChannels"])

    return VersionDB(versions, channels, VersionNumber(parsed["Version"]))
end

"""
    write_versiondb(path::AbstractString, db::VersionDB)

Serialize `db` into the shape `juliaup` deserializes. Keys are sorted so
republishing an unchanged database produces an unchanged file.
"""
function write_versiondb(path::AbstractString, db::VersionDB)
    mkpath(dirname(path))

    document = Dict(
        "AvailableVersions" =>
            Dict(key => Dict("UrlPath" => db.versions[key])
                 for key in sort(collect(keys(db.versions)))),
        "AvailableChannels" =>
            Dict(key => Dict("Version" => db.channels[key])
                 for key in sort(collect(keys(db.channels)))),
        "Version" => string(db.dbversion))

    open(path, "w") do file
        write(file, JSON.json(document))
    end

    return path
end

"""
    add_version!(db, fullversion, urlpath) -> VersionDB

Register an installable version. `urlpath` is resolved against the server base,
so pass a relative path when the tarballs are served from the same host and an
absolute URL otherwise.
"""
function add_version!(db::VersionDB,
                      fullversion::AbstractString,
                      urlpath::AbstractString)
    db.versions[fullversion] = urlpath
    return db
end

"""
    add_channel!(db, channel, fullversion) -> VersionDB

Point `channel` at an already registered version. A channel referring to an
unknown version would leave `juliaup` reporting a missing download url only
once a user tries to install it.
"""
function add_channel!(db::VersionDB,
                      channel::AbstractString,
                      fullversion::AbstractString)
    if !haskey(db.versions, fullversion)
        error("Can not add channel `$channel`: version `$fullversion` is " *
              "not in the database. Register it with `add_version!` first.")
    end

    db.channels[channel] = fullversion

    return db
end

"""
    merge(base::VersionDB, overlay::VersionDB) -> VersionDB

Combine two databases, with `overlay` winning on conflicts and providing the
resulting database version. This is how a mirror keeps the stock channels
working while adding its own.
"""
function Base.merge(base::VersionDB, overlay::VersionDB)
    return VersionDB(merge(base.versions, overlay.versions),
                     merge(base.channels, overlay.channels),
                     overlay.dbversion)
end

"""
    next_dbversion(upstream, published = upstream) -> VersionNumber

Return a database version greater than both `upstream` and whatever was
`published` previously.

`juliaup` replaces its cached database only when the number it reads exceeds
both the number compiled into its own binary and its local copy, and it logs
nothing when it does not. Publishing at or below the public number therefore
makes a distribution invisible with no diagnostic at all.
"""
function next_dbversion(upstream::VersionNumber,
                        published::VersionNumber = upstream)
    highest = max(upstream, published)

    return VersionNumber(highest.major, highest.minor, highest.patch + 1)
end
