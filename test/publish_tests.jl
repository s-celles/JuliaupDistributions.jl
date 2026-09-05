@testitem "Publishing a distribution" begin
    using JuliaupDistributions
    using JuliaupDistributions: JULIAUP_TARGETS, DBVERSION_FILES,
                                read_versiondb

    site = mktempdir()

    dist = Distribution(;
        channel = "myapp-1.2.0",
        julia_version = v"1.12.7",
        build_tag = "myapp-1.2.0",
        name = "myapp",
        version = "1.2.0",
        asset_base = "https://github.com/acme/myapp/releases/download/v1.2.0",
        mirror = false,
        dbversion = v"1.0.200")

    publish(dist, site; assets = [(:linux, :x86_64), (:macos, :aarch64)])

    # All four pointer files, all carrying the same number: a client on `dev`
    # or `releasepreview` reads its own file and 404s on a database never
    # written.
    for name in DBVERSION_FILES
        path = joinpath(site, "juliaup", name)
        @test isfile(path)
        @test strip(read(path, String)) == "1.0.200"
    end
    @test length(DBVERSION_FILES) == 4

    # One database per target triple, and nothing else
    dbdir = joinpath(site, "juliaup", "versiondb")
    written = readdir(dbdir)
    @test length(written) == 13

    for target in JULIAUP_TARGETS
        @test "versiondb-1.0.200-$target.json" in written
    end

    linux = read_versiondb(joinpath(dbdir,
        "versiondb-1.0.200-x86_64-unknown-linux-gnu.json"))

    @test linux.dbversion == v"1.0.200"
    @test haskey(linux.channels, "myapp-1.2.0")

    fullversion = linux.channels["myapp-1.2.0"]
    @test fullversion == "1.12.7+myapp-1x2x0.x64.linux.gnu"
    @test linux.versions[fullversion] ==
        "https://github.com/acme/myapp/releases/download/v1.2.0/" *
        "myapp-1.2.0-linux-x86_64.tar.gz"

    # An architecture alias, as upstream publishes alongside every channel
    @test linux.channels["myapp-1.2.0~x64"] == fullversion

    # The musl database is the one a stock Linux juliaup actually reads
    musl = read_versiondb(joinpath(dbdir,
        "versiondb-1.0.200-x86_64-unknown-linux-musl.json"))
    @test musl.channels == linux.channels
    @test musl.versions == linux.versions

    # macOS aarch64 lands only in the Apple Silicon database
    darwin = read_versiondb(joinpath(dbdir,
        "versiondb-1.0.200-aarch64-apple-darwin.json"))
    @test darwin.channels["myapp-1.2.0"] ==
        "1.12.7+myapp-1x2x0.aarch64.apple.darwin14"

    intel = read_versiondb(joinpath(dbdir,
        "versiondb-1.0.200-x86_64-apple-darwin.json"))
    @test !haskey(intel.channels, "myapp-1.2.0")

    # Standalone mode carries our channels only
    @test !haskey(linux.channels, "release")
    @test length(linux.versions) == 1
end

@testitem "Publishing on top of a mirrored database" begin
    using JuliaupDistributions
    using JuliaupDistributions: JULIAUP_TARGETS, VersionDB, read_versiondb

    fixture = joinpath(@__DIR__, "fixtures",
                       "versiondb-1.0.92-x86_64-unknown-linux-gnu.json")

    site = mktempdir()

    dist = Distribution(;
        channel = "myapp",
        julia_version = v"1.12.7",
        build_tag = "myapp-1.2.0",
        name = "myapp",
        version = "1.2.0",
        asset_base = "https://example.com/assets",
        mirror = false,
        dbversion = v"1.0.200")

    upstream = Dict{String, VersionDB}(
        target => read_versiondb(fixture) for target in JULIAUP_TARGETS)

    publish(dist, site; assets = [(:linux, :x86_64)], upstream)

    db = read_versiondb(joinpath(site, "juliaup", "versiondb",
        "versiondb-1.0.200-x86_64-unknown-linux-gnu.json"))

    # Stock channels keep working next to ours — the point of mirroring
    @test db.channels["release"] == "1.12.7+0.x64.linux.gnu"
    @test db.channels["lts"] == "1.10.12+0.x64.linux.gnu"
    @test db.channels["myapp"] == "1.12.7+myapp-1x2x0.x64.linux.gnu"
    @test length(db.versions) == 5
    @test db.dbversion == v"1.0.200"
end

@testitem "Relative asset paths stay portable" begin
    using JuliaupDistributions
    using JuliaupDistributions: read_versiondb

    site = mktempdir()

    # A site that also serves the tarballs keeps UrlPath relative, so the
    # mirror can move host without rewriting the database. JuliaHub does this.
    dist = Distribution(;
        channel = "myapp",
        julia_version = v"1.12.7",
        build_tag = "myapp-1.2.0",
        name = "myapp",
        version = "1.2.0",
        asset_base = "assets",
        mirror = false,
        dbversion = v"1.0.200")

    publish(dist, site; assets = [(:linux, :x86_64)])

    db = read_versiondb(joinpath(site, "juliaup", "versiondb",
        "versiondb-1.0.200-x86_64-unknown-linux-gnu.json"))

    @test db.versions["1.12.7+myapp-1x2x0.x64.linux.gnu"] ==
        "assets/myapp-1.2.0-linux-x86_64.tar.gz"
end

@testitem "Server URL validation" begin
    using JuliaupDistributions

    common = (; channel = "myapp", julia_version = v"1.12.7",
              build_tag = "myapp-1.2.0", name = "myapp", version = "1.2.0")

    # juliaup refuses a non-HTTPS server unless it is loopback, so a bad value
    # should fail at publish time rather than on every user's machine.
    @test_throws ErrorException Distribution(;
        common..., server = "http://example.com")

    @test_throws ErrorException Distribution(;
        common..., server = "ftp://example.com")

    # Loopback over plain HTTP is explicitly allowed by juliaup
    @test Distribution(; common...,
                       server = "http://127.0.0.1:8080") isa Distribution
    @test Distribution(; common...,
                       server = "https://example.com") isa Distribution
end

@testitem "Client wrappers" begin
    using JuliaupDistributions

    destination = mktempdir()

    dist = Distribution(;
        channel = "myapp",
        julia_version = v"1.12.7",
        build_tag = "myapp-1.2.0",
        name = "myapp",
        version = "1.2.0",
        server = "https://acme.github.io/myapp")

    install_wrappers(dist, destination)

    for name in ["myapp-juliaup", "myapp-julia",
                 "myapp-juliaup.ps1", "myapp-julia.ps1"]
        @test isfile(joinpath(destination, name))
    end

    juliaup = read(joinpath(destination, "myapp-juliaup"), String)

    @test occursin("https://acme.github.io/myapp", juliaup)
    @test occursin("JULIAUP_SERVER", juliaup)

    # The depot is isolated so the user's stock juliaup is left alone
    @test occursin("JULIAUP_DEPOT_PATH", juliaup)
    @test occursin("juliaup-depots", juliaup)
    @test occursin("acme.github.io", juliaup)

    if Sys.isunix()
        @test (stat(joinpath(destination, "myapp-juliaup")).mode & 0o111) != 0
    end

    powershell = read(joinpath(destination, "myapp-juliaup.ps1"), String)
    @test occursin("JULIAUP_SERVER", powershell)
    @test occursin("https://acme.github.io/myapp", powershell)

    # Wrappers pointing nowhere would be worse than none at all
    without = Distribution(; channel = "myapp", julia_version = v"1.12.7",
                           build_tag = "myapp-1.2.0", name = "myapp",
                           version = "1.2.0")
    @test_throws ErrorException install_wrappers(without, mktempdir())
end

@testitem "Distribution from a project directory" begin
    using JuliaupDistributions

    project = mktempdir()
    write(joinpath(project, "Project.toml"),
          "name = \"MyApp\"\nuuid = \"$(repeat("0", 8))-0000-0000-0000-$(repeat("0", 12))\"\nversion = \"2.3.4\"\n")
    write(joinpath(project, "Manifest.toml"),
          "julia_version = \"1.11.9\"\nmanifest_format = \"2.0\"\n")

    dist = Distribution(project; server = "https://example.com")

    @test dist.name == "myapp"
    @test dist.version == "2.3.4"
    @test dist.julia_version == v"1.11.9"
    @test dist.channel == "myapp-2.3.4"

    # An explicit keyword still wins over what the project says
    @test Distribution(project; channel = "nightly").channel == "nightly"
end
