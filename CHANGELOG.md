# Changelog

All notable changes to the CashLenX client are recorded here. Entries use
semantic product versions and describe shipped client behavior, not deployment
state.

## [Unreleased]

## [1.0.5] - 2026-10-10

### Fixed

- Bundled and preloaded repository-owned Noto Sans SC and TC interface subsets
  so Chinese text renders completely on the first visible Flutter frame.
- Preserved the language selected on the unauthenticated screen when entering
  Demo mode while continuing to reset Demo finance and profile data.

## [1.0.4] - 2026-10-09

### Fixed

- Normalized real and demo monthly-comparison responses into an ordered
  January-to-December series with zero-filled missing months.
- Made all twelve localized month labels visible in the statistics chart on
  compact and wide layouts without relying on hidden horizontal scrolling.
- Kept category editor requests aligned with the Server's persisted `emoji`
  and `bg_color` fields so refreshed category lists retain customization.

## [1.0.3] - 2026-10-09

### Changed

- Replaced the CashLenX launcher and product branding with the unified
  camera-and-cash artwork across Android, iOS, macOS, Windows, Flutter Web/PWA,
  splash, authentication, first-login setup, and About surfaces.

- Upgraded CI and the revision-pinned client toolchain to Flutter 3.47.5 / Dart
  3.13.4 and refreshed the locked dependency graph, including current major
  releases for routing, secure storage, injection, equality, and code
  generation.
- Bound candidate image tags and metadata to the normalized public web
  configuration profile and SHA-256 fingerprint, and made runtime start use
  only an already present image without pulling.
- Made build, start, stop, verification, and image packaging portable across
  Docker Compose and nerdctl 2.2 with pre-mutation capability checks and
  configured image identity, value-safe start output, and bounded readiness.
- Added one-shot status/doctor diagnostics, bounded logs, verified effective
  image identity, and observable graceful, forced, and repeated-stop outcomes.

## [1.0.0-rc.1] - 2026-09-16

### Added

- Traceable container packaging with semantic version, exact source revision,
  input-set digest, image identity, and SHA-256 artifact sidecars.

### Changed

- Made `/api/v1` the default stable API path while retaining Server-owned
  `/api/v0` compatibility for previously built clients.
- Aligned the Flutter package with the coordinated v1 release-candidate line.
