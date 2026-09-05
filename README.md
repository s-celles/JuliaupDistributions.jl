# JuliaupDistributions.jl

[![CI](https://github.com/s-celles/JuliaupDistributions.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/s-celles/JuliaupDistributions.jl/actions/workflows/CI.yml)
[![Docs dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://s-celles.github.io/JuliaupDistributions.jl/dev)

Publish a Julia distribution so it can be installed with
[`juliaup`](https://github.com/JuliaLang/juliaup).

`juliaup` downloads from whatever host `JULIAUP_SERVER` points at, so
distributing a bundled Julia through it needs no fork and no dedicated
infrastructure — only a handful of static files. Any static host serves them,
while the tarballs stay wherever they already live. This is the approach
JuliaHub uses to distribute Dyad.

```julia
using JuliaupDistributions

dist = Distribution(;
    channel = "myapp-1.2.0",
    julia_version = v"1.12.7",
    build_tag = "myapp-1.2.0",
    name = "myapp",
    version = "1.2.0",
    server = "https://acme.github.io/myapp",
    asset_base = "https://github.com/acme/myapp/releases/download/v1.2.0")

publish(dist, "site"; assets = [(:linux, :x86_64), (:macos, :aarch64)])
```

Serve `site/` over HTTPS, and users install with:

```
export JULIAUP_SERVER=https://acme.github.io/myapp
juliaup add myapp-1.2.0
julia +myapp-1.2.0
```

Or from a release pipeline, without writing Julia:

```
julia -m JuliaupDistributions --site=site --channel=myapp-1.2.0 \
    --name=myapp --version=1.2.0 --julia-version=1.12.7 \
    --server=https://acme.github.io/myapp \
    --asset-base=https://github.com/acme/myapp/releases/download/v1.2.0 \
    --platform=linux/x86_64 --platform=macos/aarch64 --wrappers
```

`examples/publish-to-pages.yml` is a ready-made GitHub Actions workflow doing
exactly that on each release.

## What it handles for you

The database is small but unforgiving. This package covers the parts that are
easy to get wrong by hand:

- **Thirteen target triples.** A database is named after the triple of the
  *`juliaup` client*, not the Julia build. The Linux client is musl-static but
  runs on glibc hosts, so a Linux build must appear in both databases; an Apple
  Silicon client lists x86_64 builds for Rosetta 2.
- **Four pointer files.** `juliaup` reads only the one matching the channel it
  was installed from, so all four are written and kept in agreement.
- **A database version above the public one.** `juliaup` ignores a database
  whose number does not exceed the one built into its binary, and says nothing
  when it does.
- **Build tags without dots.** `juliaup` reads the architecture from the second
  dot-separated component of the build metadata, so a tag containing dots
  resolves to a nonsense architecture. JuliaHub hit this with early Dyad
  releases.
- **Mirroring**, so stock channels keep working for users pointed at your
  server.

## Verified end to end

The test suite installs a published channel with a **real `juliaup` client**
over a loopback HTTP server, covering both relative and absolute `UrlPath`.
`juliaup` permits plain HTTP on loopback, which makes the whole flow testable
offline:

```
julia --project=. test/e2e_tests.jl
```

`examples/real_julia_demo.jl` goes further, with nothing mocked at all: it reads
the public database, takes the real `release` entry, republishes it under a
channel name of its own, and lets `juliaup` download and install the actual
Julia from julialang.org.

```
julia --project=. examples/real_julia_demo.jl
```

It also shows the shortcut worth knowing when developing: `juliaup` reads its
database straight out of its depot, so you can test a database without a server
or a Pages deploy.

## Origin

Extracted from a
[pull request to AppBundler.jl](https://github.com/PeaceFounder/AppBundler.jl/pull/45)
at its maintainer's suggestion, so the database can be tested on its own and
reused outside AppBundler.

## Licence

MIT. See [LICENSE.md](LICENSE.md), and [SECURITY.md](SECURITY.md) for reporting
vulnerabilities.
