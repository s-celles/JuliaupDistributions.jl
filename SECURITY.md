# Security Policy

## Supported versions

The latest released version receives security fixes. Older versions are not
maintained.

## Reporting a vulnerability

Please report vulnerabilities **privately**, through GitHub's security
advisory workflow:

[Report a vulnerability](https://github.com/s-celles/JuliaupDistributions.jl/security/advisories/new)

This opens a draft GHSA visible only to the maintainers. Do not open a public
issue for a vulnerability, and do not disclose details until a fix is released.

You can expect an acknowledgement within a week, and an assessment with a
planned remedy or an explanation of why the report is not treated as a
vulnerability within a month.

## Threat model worth knowing

This package writes the static files a `juliaup` client reads to decide what to
download, so it sits on a supply chain path. Two properties matter:

- **`UrlPath` is resolved against the server base.** An absolute URL in a
  database entry sends clients to another host entirely. Review the
  `asset_base` you publish, especially if it comes from CI configuration.
- **A mirrored database carries upstream entries verbatim.** When mirroring,
  what you republish is what the upstream server served you at that moment;
  this package does not verify upstream signatures, because juliaup's database
  format carries none.

Neither is a vulnerability in this package, but both are worth understanding
before publishing a distribution others install from.
