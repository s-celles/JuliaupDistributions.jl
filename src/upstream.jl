"""
    fetch_dbversion(; server = DEFAULT_SERVER, channel = :release)

Download the database version a server currently advertises for `channel`,
which is one of `:release`, `:releasepreview` or `:dev`.
"""
function fetch_dbversion(; server::AbstractString = DEFAULT_SERVER,
                         channel::Symbol = :release)
    name = channel === :release ? "RELEASECHANNELDBVERSION" :
           channel === :releasepreview ? "RELEASEPREVIEWCHANNELDBVERSION" :
           channel === :dev ? "DEVCHANNELDBVERSION" :
           error("Unknown juliaup channel `$channel`. Expected :release, " *
                 ":releasepreview or :dev.")

    destination = tempname()

    Downloads.download(rstrip(server, '/') * "/juliaup/" * name, destination)

    return VersionNumber(strip(read(destination, String)))
end

"""
    fetch_versiondb(target; server = DEFAULT_SERVER, dbversion) -> VersionDB

Download the version database a `juliaup` client with the given target triple
would read.
"""
function fetch_versiondb(target::AbstractString;
                         server::AbstractString = DEFAULT_SERVER,
                         dbversion::VersionNumber = fetch_dbversion(; server))
    target in JULIAUP_TARGETS ||
        error("`$target` is not a juliaup target triple")

    url = rstrip(server, '/') *
          "/juliaup/versiondb/versiondb-$dbversion-$target.json"
    destination = tempname()

    Downloads.download(url, destination)

    return read_versiondb(destination)
end

"""
    fetch_upstream(; server = DEFAULT_SERVER, dbversion)

Download the version database for every target triple, keyed by triple. This is
the base a mirror merges its own channels into.
"""
function fetch_upstream(; server::AbstractString = DEFAULT_SERVER,
                        dbversion::VersionNumber = fetch_dbversion(; server))
    @info "Fetching upstream juliaup databases at $dbversion from $server"

    return Dict{String, VersionDB}(
        target => fetch_versiondb(target; server, dbversion)
        for target in JULIAUP_TARGETS)
end
