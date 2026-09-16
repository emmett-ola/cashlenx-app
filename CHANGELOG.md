# Changelog

All notable changes to the CashLenX client are recorded here. Entries use
semantic product versions and describe shipped client behavior, not deployment
state.

## [1.0.0-rc.1] - 2026-09-16

### Added

- Traceable container packaging with semantic version, exact source revision,
  input-set digest, image identity, and SHA-256 artifact sidecars.

### Changed

- Made `/api/v1` the default stable API path while retaining Server-owned
  `/api/v0` compatibility for previously built clients.
- Aligned the Flutter package with the coordinated v1 release-candidate line.
