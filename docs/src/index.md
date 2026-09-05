# JuliaupDistributions.jl

Publish a Julia distribution so it can be installed with `juliaup`.

`juliaup` downloads from whatever host `JULIAUP_SERVER` points at. Distributing
a bundled Julia through it therefore needs no fork of `juliaup` and no dedicated
infrastructure — only a handful of static files, which any static host can serve
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

Serve `site/` over HTTPS and users install with:

```
export JULIAUP_SERVER=https://acme.github.io/myapp
juliaup add myapp-1.2.0
julia +myapp-1.2.0
```

## Why a package

The database is small but fiddly: thirteen target triples, four pointer files,
and two failure modes that produce no diagnostic whatsoever. Encapsulating it
means a build pipeline only has to say which platforms it produced, and the
awkward parts stay tested in one place.

## Installation

```julia
using Pkg
Pkg.add("JuliaupDistributions")
```
