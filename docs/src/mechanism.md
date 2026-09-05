# How juliaup works

Understanding the three requests `juliaup` makes explains every design choice
in this package.

`juliaup add <channel>` performs:

1. `GET <server>/juliaup/RELEASECHANNELDBVERSION` — one line, the number of the
   current database.
2. `GET <server>/juliaup/versiondb/versiondb-<dbversion>-<target>.json` — the
   database, cached locally afterwards.
3. `GET <UrlPath>` — the tarball, at the path the database recorded.

Everything between is a local lookup: the channel resolves to a full version
string in `AvailableChannels`, which resolves to a `UrlPath` in
`AvailableVersions`.

## UrlPath is relative to the server

`UrlPath` is resolved against the server base, which makes two layouts possible:

- a **relative** path keeps the database portable — move the whole site to
  another host and nothing has to be rewritten;
- an **absolute** url points elsewhere entirely, so a database on GitHub Pages
  can serve tarballs from a releases page without a byte passing through Pages.

## Target triples

A database file is named after the Rust target triple of the **`juliaup` client
binary**, not the Julia build it installs. There are 13, and this package writes
all of them. Two consequences are easy to get wrong by hand:

- The Linux `juliaup` is a musl-static binary that also runs on glibc hosts, so
  a Linux build has to appear in both the `-musl` and `-gnu` databases. The same
  holds for the Windows `-gnu`/`-msvc` pair. Upstream publishes these as
  identical files.
- A database carries every architecture its client can *execute*. A 64 bit
  client lists 32 bit builds, and an Apple Silicon client lists x86_64 builds so
  they can run under Rosetta 2.

## Two silent failure modes

Both are worth knowing because neither produces an error message.

**A database version at or below the public one is ignored.** `juliaup` replaces
its cached database only when the number it reads exceeds *both* the number
compiled into its own binary and its local copy — and it logs nothing when it
does not. Your channels simply never appear. [`next_dbversion`](@ref) exists for
this, and [`publish`](@ref) resolves the number against upstream automatically.

**All four pointer files must agree.** `juliaup` reads exactly one, depending on
the channel it was itself installed from: `release` clients read
`RELEASECHANNELDBVERSION`, `releasepreview` clients
`RELEASEPREVIEWCHANNELDBVERSION`, `dev` clients `DEVCHANNELDBVERSION`. This
package writes all four with the same number, so a user on a preview client does
not take a 404 on a database the mirror never wrote.

## Version strings

A version is identified by a string like `1.12.7+myapp-1x2x0.x64.linux.gnu`: the
Julia version, then build metadata whose components are the build tag,
architecture, vendor and operating system.

`juliaup` splits that metadata on `.` and reads the **second** component as the
architecture. A build tag containing dots shifts the index and the entry
resolves to a nonsense architecture. JuliaHub hit this with early Dyad releases
— `1.11.8+dyad-2.1.0-rc3.x64.linux.gnu` parses its architecture as `1` — and
later switched to `dyad-2x1x0-rc3`. [`sanitize_build_tag`](@ref) does this for
you, which is why `myapp-1.2.0` becomes `myapp-1x2x0`.
