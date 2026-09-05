# Reference

```@docs
JuliaupDistributions.JuliaupDistributions
```

## Distributions

```@docs
JuliaupDistributions.Distribution
JuliaupDistributions.publish
JuliaupDistributions.install_wrappers
JuliaupDistributions.wrapper_scripts
JuliaupDistributions.asset_url
```

## Command line

```@docs
JuliaupDistributions.main
```

## The version database

```@docs
JuliaupDistributions.VersionDB
JuliaupDistributions.read_versiondb
JuliaupDistributions.write_versiondb
JuliaupDistributions.add_version!
JuliaupDistributions.add_channel!
JuliaupDistributions.next_dbversion
```

## Upstream

```@docs
JuliaupDistributions.fetch_dbversion
JuliaupDistributions.fetch_versiondb
JuliaupDistributions.fetch_upstream
```

## Platforms

```@docs
JuliaupDistributions.full_version_string
JuliaupDistributions.sanitize_build_tag
JuliaupDistributions.platform_suffix
JuliaupDistributions.juliaup_arch
JuliaupDistributions.targets_for
JuliaupDistributions.target_platform
```

## Internals

```@docs
JuliaupDistributions.register!
JuliaupDistributions.published_dbversion
JuliaupDistributions.validate_server
JuliaupDistributions.default_depot
JuliaupDistributions.project_julia_version
```
