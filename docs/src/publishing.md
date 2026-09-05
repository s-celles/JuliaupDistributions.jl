# Publishing

## Mirroring

By default a distribution *mirrors*: the upstream database is downloaded, your
channels are merged into it, and the result is republished. Users keep
`release`, `lts` and every stock channel while pointed at your server. This is
what JuliaHub does — their linux-x64 database is the public one plus their own
entries.

```julia
publish(dist, "site"; assets = [(:linux, :x86_64)])
```

Set `mirror = false` to publish your channels alone. That is the right choice
for an air-gapped site, where reaching `julialang-s3.julialang.org` at publish
time is not possible, at the cost of stock channels no longer resolving for
anyone using your server.

You can also supply the upstream databases yourself, which is what the tests do:

```julia
publish(dist, "site"; assets = [(:linux, :x86_64)], upstream = my_databases)
```

## Client wrappers

[`install_wrappers`](@ref) writes small scripts that set `JULIAUP_SERVER` and,
importantly, `JULIAUP_DEPOT_PATH`:

```bash
export JULIAUP_SERVER=https://acme.github.io/myapp
export JULIAUP_DEPOT_PATH="${HOME}/.julia/juliaup-depots/acme.github.io"

exec juliaup "$@"
```

The isolated depot keeps your distribution and the user's stock `juliaup` from
sharing channels or state, so `myapp-juliaup status` and `juliaup status` list
different things and neither can disturb the other. Users who prefer not to
install wrappers can export the same two variables themselves.

## From the command line

A release pipeline does not have to write Julia. The package is also an app:

```
julia -m JuliaupDistributions --site=site --channel=myapp-1.2.0 \
    --name=myapp --version=1.2.0 --julia-version=1.12.7 \
    --server=https://acme.github.io/myapp \
    --asset-base=https://github.com/acme/myapp/releases/download/v1.2.0 \
    --platform=linux/x86_64 --platform=macos/aarch64 --wrappers
```

`--help` lists every option. The tarballs are built elsewhere, by whatever
means suits you; this only writes the database that points at them, following
the naming convention `<name>-<version>-<os>-<arch>.tar.gz`.

## Continuous delivery

`examples/publish-to-pages.yml` in this repository is a ready-made GitHub
Actions workflow: it publishes the database to GitHub Pages on each release,
referencing the tarballs already attached to that release.

Two details matter in CI:

- Seed the site with the number already published before calling `publish`, so
  republishing keeps climbing rather than reusing a number clients have cached.
  `publish` reads `<site>/juliaup/RELEASECHANNELDBVERSION` for exactly this.
- Point `asset_base` at the release download URL, so the database references
  the tarballs where they already are.

## Testing without deploying

`juliaup` reads its database straight out of its depot, so a database can be
dropped in and used without a server or a Pages deploy:

```
$JULIAUP_DEPOT_PATH/juliaup/versiondb-<target>.json
```

`<target>` is the Rust triple of the *client*; the simplest way to learn it is
to look at the name `juliaup` gave its own cached copy in `~/.julia/juliaup/`.
The database version has to exceed the number built into the juliaup binary,
otherwise the file is ignored with no diagnostic.

`examples/real_julia_demo.jl` does exactly this, end to end and with nothing
mocked: it reads the public database, takes the real `release` entry,
republishes it under a channel name of its own, and lets `juliaup` download and
install the actual Julia from julialang.org.

```
julia --project=. examples/real_julia_demo.jl
```

Because the database is served from somewhere other than julialang.org, the
entry's relative `UrlPath` has to become absolute — the same mechanism that
lets a database on GitHub Pages point at tarballs on a releases page.

## Verifying a published site

The one check that proves a site works is installing from it. The package's own
end to end test does this against a real `juliaup` client over a loopback HTTP
server — `juliaup` permits plain HTTP on loopback, which makes the whole flow
testable offline:

```
julia --project=. test/e2e_tests.jl
```
