# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]

Initial release. Extracted from a
[pull request to AppBundler.jl](https://github.com/PeaceFounder/AppBundler.jl/pull/45)
at the maintainer's suggestion, so the juliaup database can be tested on its
own and reused outside AppBundler.

### Added

- `VersionDB`, with reading, writing, merging and version bumping of a juliaup
  version database.
- Platform tables covering the 13 client target triples, the `<arch>.<vendor>.<os>`
  suffixes and the compatible-architecture expansion, all derived from the
  published upstream databases rather than guessed.
- `Distribution` and `publish`, writing the complete static tree a juliaup
  client reads: 13 databases plus the four `*DBVERSION` pointer files.
- Mirroring, so the stock channels keep working for users pointed at a custom
  server.
- `install_wrappers`, generating client wrappers that set `JULIAUP_SERVER` and
  isolate `JULIAUP_DEPOT_PATH`.
- A command line entry point (`julia -m JuliaupDistributions`), so a release
  pipeline can publish without writing Julia.
- `examples/publish-to-pages.yml`, a GitHub Actions workflow publishing a
  distribution to GitHub Pages on each release.
- An end to end test that installs a published channel with a real `juliaup`
  client over a loopback HTTP server, covering both relative and absolute
  `UrlPath`.

[Unreleased]: https://github.com/s-celles/JuliaupDistributions.jl/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/s-celles/JuliaupDistributions.jl/releases/tag/v0.1.0
