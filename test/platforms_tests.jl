@testitem "Build tag sanitization" begin
    using JuliaupDistributions: sanitize_build_tag

    # juliaup splits the build metadata on "." and reads the second component
    # as the architecture. A tag carrying dots shifts that index and the entry
    # resolves to a bogus architecture, which is why JuliaHub moved from
    # `dyad-2.1.0-rc3` to `dyad-2x1x0-rc3`.
    @test sanitize_build_tag("2.1.0-rc3") == "2x1x0-rc3"
    @test sanitize_build_tag("dyad-3.3.0") == "dyad-3x3x0"
    @test sanitize_build_tag("3.2.0-next.87") == "3x2x0-nextx87"
    @test sanitize_build_tag("0") == "0"

    @test_throws ErrorException sanitize_build_tag("")
    @test_throws ErrorException sanitize_build_tag("has space")
end

@testitem "Full version strings" begin
    using JuliaupDistributions: platform_suffix, full_version_string

    @test platform_suffix(:linux, :x86_64) == "x64.linux.gnu"
    @test platform_suffix(:linux, :i686) == "x86.linux.gnu"
    @test platform_suffix(:linux, :aarch64) == "aarch64.linux.gnu"
    @test platform_suffix(:macos, :x86_64) == "x64.apple.darwin14"
    @test platform_suffix(:macos, :aarch64) == "aarch64.apple.darwin14"
    @test platform_suffix(:windows, :x86_64) == "x64.w64.mingw32"
    @test platform_suffix(:windows, :i686) == "x86.w64.mingw32"
    @test platform_suffix(:freebsd, :x86_64) == "x64.unknown.freebsd11.1"

    @test_throws ErrorException platform_suffix(:macos, :i686)
    @test_throws ErrorException platform_suffix(:haiku, :x86_64)

    # Matches the shape of upstream entries such as `1.12.7+0.x64.linux.gnu`
    @test full_version_string(v"1.12.7", "0", :linux, :x86_64) ==
        "1.12.7+0.x64.linux.gnu"

    # Build tags are sanitized on the way in, so a caller cannot construct a
    # broken entry
    @test full_version_string(v"1.12.7", "myapp-1.2.0", :linux, :x86_64) ==
        "1.12.7+myapp-1x2x0.x64.linux.gnu"

    # The architecture must survive juliaup's own parsing: build metadata split
    # on ".", second component is the architecture.
    for (os, arch, expected) in [(:linux, :x86_64, "x64"),
                                 (:macos, :aarch64, "aarch64"),
                                 (:windows, :i686, "x86")]
        full = full_version_string(v"1.11.9", "app-2.0.0", os, arch)
        parts = split(split(full, '+')[2], '.')

        @test length(parts) >= 4
        @test parts[2] == expected
    end
end

@testitem "Target triples" begin
    using JuliaupDistributions: JULIAUP_TARGETS, targets_for, target_platform

    @test length(JULIAUP_TARGETS) == 13
    @test allunique(JULIAUP_TARGETS)

    # The triple describes the juliaup client binary, not the Julia build. The
    # Linux client is musl-static but runs on glibc hosts, so a Linux build has
    # to land in both databases.
    @test Set(targets_for(:linux, :x86_64)) ==
        Set(["x86_64-unknown-linux-gnu", "x86_64-unknown-linux-musl"])

    # A 32 bit build is also reachable from a 64 bit client
    @test "x86_64-unknown-linux-gnu" in targets_for(:linux, :i686)
    @test "i686-unknown-linux-gnu" in targets_for(:linux, :i686)
    @test "i686-unknown-linux-gnu" ∉ targets_for(:linux, :x86_64)

    # Rosetta 2: an x86_64 macOS build is installable from Apple Silicon
    @test Set(targets_for(:macos, :x86_64)) ==
        Set(["x86_64-apple-darwin", "aarch64-apple-darwin"])
    @test targets_for(:macos, :aarch64) == ["aarch64-apple-darwin"]

    @test Set(targets_for(:windows, :x86_64)) ==
        Set(["x86_64-pc-windows-gnu", "x86_64-pc-windows-msvc"])

    @test targets_for(:freebsd, :x86_64) == ["x86_64-unknown-freebsd"]

    # Every target a build maps to must be one juliaup actually asks for
    for os in [:linux, :macos, :windows, :freebsd],
        arch in [:x86_64, :i686, :aarch64]

        targets = try
            targets_for(os, arch)
        catch
            continue
        end

        @test all(in(JULIAUP_TARGETS), targets)
    end

    # Round trip: a triple resolves back to a platform it serves
    for target in JULIAUP_TARGETS
        os, arch = target_platform(target)
        @test os isa Symbol && arch isa Symbol
    end
end
