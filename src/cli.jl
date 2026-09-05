"""
    run_cli(ARGS) -> Int

Command line entry point, so a release pipeline can publish without writing
Julia:

```
julia -m JuliaupDistributions --site=site --channel=myapp-1.2.0 \\
    --julia-version=1.12.7 --name=myapp --version=1.2.0 \\
    --server=https://acme.github.io/myapp \\
    --asset-base=https://github.com/acme/myapp/releases/download/v1.2.0 \\
    --platform=linux/x86_64 --platform=macos/aarch64 --wrappers
```

The assets themselves are built elsewhere; this only writes the database that
points at them.

Invoking it as `julia -m JuliaupDistributions` needs Julia 1.11 or newer, which
is where `@main` entry points were introduced. On 1.10 call this function
directly.
"""
function run_cli(ARGS)
    if isempty(ARGS) || any(in(("--help", "-h")), ARGS)
        println(HELP_TEXT)
        return isempty(ARGS) ? 1 : 0
    end

    options = parse_args(ARGS)

    dist = Distribution(; channel = options[:channel],
                        julia_version = options[:julia_version],
                        build_tag = something(options[:build_tag],
                                              options[:channel]),
                        name = options[:name],
                        version = options[:version],
                        server = options[:server],
                        asset_base = options[:asset_base],
                        mirror = options[:mirror],
                        dbversion = options[:dbversion])

    publish(dist, options[:site]; assets = options[:platforms])

    options[:wrappers] &&
        install_wrappers(dist, joinpath(options[:site], "wrappers"))

    server = isempty(dist.server) ? "https://your.site" : dist.server

    println("""

    The site is ready at $(options[:site]). Serve it over HTTPS, then users
    install the distribution with:

        export JULIAUP_SERVER=$server
        juliaup add $(dist.channel)
        julia +$(dist.channel)
    """)

    return 0
end

function parse_args(raw)
    options = Dict{Symbol, Any}(:site => "site",
                                :channel => nothing,
                                :julia_version => VERSION,
                                :build_tag => nothing,
                                :name => nothing,
                                :version => nothing,
                                :server => "",
                                :asset_base => "assets",
                                :mirror => true,
                                :dbversion => nothing,
                                :wrappers => false,
                                :platforms => Tuple{Symbol, Symbol}[])

    for arg in raw
        if arg == "--wrappers"
            options[:wrappers] = true
            continue
        elseif arg == "--no-mirror"
            options[:mirror] = false
            continue
        elseif arg == "--mirror"
            options[:mirror] = true
            continue
        end

        occursin('=', arg) ||
            error("Unrecognised argument `$arg`. See `--help`.")

        flag, value = split(arg, '=', limit = 2)

        if flag == "--site"
            options[:site] = value
        elseif flag == "--channel"
            options[:channel] = value
        elseif flag == "--julia-version"
            options[:julia_version] = VersionNumber(value)
        elseif flag == "--build-tag"
            options[:build_tag] = value
        elseif flag == "--name"
            options[:name] = value
        elseif flag == "--version"
            options[:version] = value
        elseif flag == "--server"
            options[:server] = value
        elseif flag == "--asset-base"
            options[:asset_base] = value
        elseif flag == "--dbversion"
            options[:dbversion] = VersionNumber(value)
        elseif flag == "--platform"
            parts = split(value, '/')
            length(parts) == 2 ||
                error("--platform expects <os>/<arch>, got `$value`")
            push!(options[:platforms],
                  (Symbol(parts[1]), Symbol(parts[2])))
        else
            error("Unrecognised option `$flag`. See `--help`.")
        end
    end

    for required in (:channel, :name, :version)
        isnothing(options[required]) &&
            error("--$(replace(string(required), '_' => '-')) is required. " *
                  "See `--help`.")
    end

    isempty(options[:platforms]) &&
        error("At least one --platform=<os>/<arch> is required. See `--help`.")

    # Checked here rather than when the wrappers are written, so an incompatible
    # combination fails before the database is published instead of leaving the
    # site half finished.
    options[:wrappers] && isempty(options[:server]) &&
        error("--wrappers needs --server=URL: a wrapper without a server " *
              "points nowhere.")

    return options
end

const HELP_TEXT = """
Usage: julia -m JuliaupDistributions [OPTIONS]

Writes the static files a juliaup client reads, so a distribution can be
installed with `juliaup add <channel>`. The tarballs themselves are built
elsewhere; this only publishes the database pointing at them.

Required:
  --channel=NAME           Channel users pass to `juliaup add`
  --name=NAME              Application name, used in asset filenames
  --version=VERSION        Application version, used in asset filenames
  --platform=OS/ARCH       A platform that was built; repeatable

Options:
  --site=DIR               Output directory for the static site
                           (default: site)
  --julia-version=VERSION  Julia version the distribution is built on
                           (default: the running version)
  --build-tag=TAG          Build identifier in the full version string
                           (default: the channel name)
  --server=URL             HTTPS base url the site will be served from,
                           written into the client wrappers
  --asset-base=URL         Base url or path the tarballs are served from.
                           Relative keeps the database portable across hosts;
                           absolute points elsewhere, such as a releases page
  --dbversion=VERSION      Database version to publish. Must exceed the public
                           one or juliaup silently ignores it; resolved
                           automatically when omitted
  --mirror / --no-mirror   Merge the upstream database in so stock channels
                           keep working (default: mirror)
  --wrappers               Also write the client wrappers into the site
  -h, --help               Show this message

Example:
  julia -m JuliaupDistributions --site=site --channel=myapp-1.2.0 \\
      --name=myapp --version=1.2.0 --julia-version=1.12.7 \\
      --server=https://acme.github.io/myapp \\
      --asset-base=https://github.com/acme/myapp/releases/download/v1.2.0 \\
      --platform=linux/x86_64 --platform=macos/aarch64 --wrappers
"""

# `julia -m Module` dispatches to a function registered with `@main`, which
# Julia 1.11 introduced. The command itself works on 1.10 through `run_cli`; it
# just cannot be reached that way, so the registration is guarded rather than
# raising the package's lower bound past the current LTS.
@static if VERSION >= v"1.11"
    function (@main)(ARGS)
        return run_cli(ARGS)
    end
end
