# Changelog

All notable changes to the CashLenX client are recorded here. Entries use
semantic product versions and describe shipped client behavior, not deployment
state.

## [Unreleased]

### Changed

- Bound candidate image tags and metadata to the normalized public web
  configuration profile and SHA-256 fingerprint, and made runtime start use
  only an already present image without pulling.
- Made build, start, stop, verification, and image packaging portable across
  Docker Compose and nerdctl 2.2 with pre-mutation capability checks and
  configured image identity, value-safe start output, and bounded readiness.

## [1.0.0-rc.1] - 2026-09-16

### Added

- Traceable container packaging with semantic version, exact source revision,
  input-set digest, image identity, and SHA-256 artifact sidecars.

### Changed

- Made `/api/v1` the default stable API path while retaining Server-owned
  `/api/v0` compatibility for previously built clients.
- Aligned the Flutter package with the coordinated v1 release-candidate line.
