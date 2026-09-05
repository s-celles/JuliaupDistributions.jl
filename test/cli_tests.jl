@testitem "Argument parsing" begin
    using JuliaupDistributions: parse_args

    options = parse_args(["--site=out",
                          "--channel=myapp-1.2.0",
                          "--name=myapp",
                          "--version=1.2.0",
                          "--julia-version=1.12.7",
                          "--platform=linux/x86_64",
                          "--platform=macos/aarch64",
                          "--no-mirror",
                          "--wrappers"])

    @test options[:site] == "out"
    @test options[:channel] == "myapp-1.2.0"
    @test options[:julia_version] == v"1.12.7"
    @test options[:platforms] == [(:linux, :x86_64), (:macos, :aarch64)]
    @test options[:mirror] == false
    @test options[:wrappers] == true

    # The build tag falls back to the channel, which is the common case
    @test isnothing(options[:build_tag])

    # Mirroring is the default, matching `publish`
    defaults = parse_args(["--channel=c", "--name=n", "--version=1",
                           "--platform=linux/x86_64"])
    @test defaults[:mirror] == true
    @test defaults[:wrappers] == false
    @test defaults[:asset_base] == "assets"
    @test defaults[:site] == "site"
end

@testitem "Argument validation" begin
    using JuliaupDistributions: parse_args

    complete = ["--channel=c", "--name=n", "--version=1",
                "--platform=linux/x86_64"]

    # Every required option is actually required, so a pipeline fails loudly
    # rather than publishing something incomplete
    for missing in ["--channel=c", "--name=n", "--version=1"]
        @test_throws ErrorException parse_args(filter(!=(missing), complete))
    end

    @test_throws ErrorException parse_args(["--channel=c", "--name=n",
                                            "--version=1"])

    @test_throws ErrorException parse_args([complete...,
                                            "--platform=linux"])
    @test_throws ErrorException parse_args([complete..., "--bogus=1"])
    @test_throws ErrorException parse_args([complete..., "positional"])
end

@testitem "Publishing through the command line" begin
    using JuliaupDistributions
    using JuliaupDistributions: JULIAUP_TARGETS, read_versiondb

    site = mktempdir()

    # The entry point is exercised the way a release pipeline calls it, so the
    # wiring between parsing, Distribution and publish stays covered.
    options = JuliaupDistributions.parse_args(
        ["--site=$site",
         "--channel=demo-1.0.0",
         "--name=demo",
         "--version=1.0.0",
         "--julia-version=1.12.7",
         "--asset-base=https://example.com/releases",
         "--platform=linux/x86_64",
         "--no-mirror"])

    dist = Distribution(; channel = options[:channel],
                        julia_version = options[:julia_version],
                        build_tag = something(options[:build_tag],
                                              options[:channel]),
                        name = options[:name],
                        version = options[:version],
                        server = options[:server],
                        asset_base = options[:asset_base],
                        mirror = options[:mirror],
                        dbversion = v"1.0.200")

    publish(dist, site; assets = options[:platforms])

    @test length(readdir(joinpath(site, "juliaup", "versiondb"))) ==
        length(JULIAUP_TARGETS)

    db = read_versiondb(joinpath(site, "juliaup", "versiondb",
        "versiondb-1.0.200-x86_64-unknown-linux-gnu.json"))

    @test db.channels["demo-1.0.0"] ==
        "1.12.7+demo-1x0x0.x64.linux.gnu"
    @test db.versions["1.12.7+demo-1x0x0.x64.linux.gnu"] ==
        "https://example.com/releases/demo-1.0.0-linux-x86_64.tar.gz"
end
