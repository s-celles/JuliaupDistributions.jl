@testitem "Version database round trip" begin
    using JuliaupDistributions: read_versiondb, write_versiondb

    fixture = joinpath(@__DIR__, "fixtures",
                       "versiondb-1.0.92-x86_64-unknown-linux-gnu.json")

    db = read_versiondb(fixture)

    @test db.dbversion == v"1.0.92"
    @test db.channels["release"] == "1.12.7+0.x64.linux.gnu"
    @test db.versions["1.12.7+0.x64.linux.gnu"] ==
        "bin/linux/x64/1.12/julia-1.12.7-linux-x86_64.tar.gz"
    @test length(db.versions) == 4
    @test length(db.channels) == 10

    # Internals are plain Dicts so the JSON implementation does not leak
    @test db.versions isa Dict{String, String}
    @test db.channels isa Dict{String, String}

    path = joinpath(mktempdir(), "versiondb.json")
    write_versiondb(path, db)
    reread = read_versiondb(path)

    @test reread.versions == db.versions
    @test reread.channels == db.channels
    @test reread.dbversion == db.dbversion

    # The serialized form must match what juliaup deserializes into
    raw = read(path, String)
    @test occursin("\"AvailableVersions\"", raw)
    @test occursin("\"AvailableChannels\"", raw)
    @test occursin("\"UrlPath\"", raw)
    @test occursin("\"Version\"", raw)
end

@testitem "Adding versions and channels" begin
    using JuliaupDistributions: read_versiondb, add_version!, add_channel!,
                                full_version_string

    fixture = joinpath(@__DIR__, "fixtures",
                       "versiondb-1.0.92-x86_64-unknown-linux-gnu.json")

    db = read_versiondb(fixture)
    fullversion = full_version_string(v"1.12.7", "myapp-1.2.0",
                                      :linux, :x86_64)

    add_version!(db, fullversion,
                 "https://example.com/myapp-1.2.0-linux-x86_64.tar.gz")
    add_channel!(db, "myapp-1.2.0", fullversion)

    @test db.versions[fullversion] ==
        "https://example.com/myapp-1.2.0-linux-x86_64.tar.gz"
    @test db.channels["myapp-1.2.0"] == fullversion

    # Upstream entries are untouched — the mirroring property that keeps
    # `juliaup add release` working against a custom server
    @test db.channels["release"] == "1.12.7+0.x64.linux.gnu"
    @test length(db.versions) == 5

    # A channel may only point at a version the database knows about
    @test_throws ErrorException add_channel!(db, "dangling",
                                             "9.9.9+0.x64.linux.gnu")
end

@testitem "Database merging" begin
    using JuliaupDistributions: VersionDB, read_versiondb

    fixture = joinpath(@__DIR__, "fixtures",
                       "versiondb-1.0.92-x86_64-unknown-linux-gnu.json")

    base = read_versiondb(fixture)

    overlay = VersionDB(Dict("1.12.7+app.x64.linux.gnu" => "assets/app.tar.gz"),
                        Dict("app" => "1.12.7+app.x64.linux.gnu"),
                        v"1.0.100")

    merged = merge(base, overlay)

    @test length(merged.versions) == 5
    @test merged.channels["app"] == "1.12.7+app.x64.linux.gnu"
    @test merged.channels["release"] == "1.12.7+0.x64.linux.gnu"

    # The overlay wins on conflicts and carries the database version
    @test merged.dbversion == v"1.0.100"

    conflicting = VersionDB(Dict{String, String}(),
                            Dict("release" => "1.10.12+0.x64.linux.gnu"),
                            v"1.0.100")
    @test merge(base, conflicting).channels["release"] ==
        "1.10.12+0.x64.linux.gnu"

    # Merging leaves the operands alone
    @test length(base.versions) == 4
    @test base.channels["release"] == "1.12.7+0.x64.linux.gnu"
end

@testitem "Database version bumping" begin
    using JuliaupDistributions: next_dbversion

    # juliaup ignores a published database whose number is not greater than the
    # one compiled into the binary, and reports nothing when it does.
    @test next_dbversion(v"1.0.92") > v"1.0.92"
    @test next_dbversion(v"1.0.92") == v"1.0.93"
    @test next_dbversion(v"1.0.92", v"1.0.124") == v"1.0.125"
    @test next_dbversion(v"1.0.130", v"1.0.124") == v"1.0.131"

    # Same major/minor line as upstream, otherwise the semver comparison stops
    # being meaningful
    @test next_dbversion(v"1.0.92").major == 1
    @test next_dbversion(v"1.0.92").minor == 0
end
