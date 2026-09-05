"""
    JuliaupDistributions

Publish a Julia distribution so it can be installed with `juliaup`.

`juliaup` downloads from whatever host `JULIAUP_SERVER` points at, so
distributing a bundled Julia through it needs no fork and no dedicated
infrastructure — only a handful of static files, which any static host can
serve while the tarballs stay wherever they already live.

The database itself is fiddly: thirteen target triples, four pointer files, and
two failure modes that produce no diagnostic at all. This package encapsulates
that, so a build pipeline only has to say which platforms it produced.

```julia
dist = Distribution(; channel = "myapp-1.2.0",
                    julia_version = v"1.12.7",
                    build_tag = "myapp-1.2.0",
                    name = "myapp", version = "1.2.0",
                    server = "https://acme.github.io/myapp",
                    asset_base = "https://github.com/acme/myapp/releases/download/v1.2.0")

publish(dist, "site"; assets = [(:linux, :x86_64), (:macos, :aarch64)])
```
"""
module JuliaupDistributions

import JSON
import Downloads
import TOML

include("platforms.jl")
include("versiondb.jl")
include("upstream.jl")
include("publish.jl")
include("wrappers.jl")
include("cli.jl")

export Distribution, VersionDB, publish, install_wrappers

end
