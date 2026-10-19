# Changelog

All notable changes to the CashLenX client are recorded here. Entries use
semantic product versions and describe shipped client behavior, not deployment
state.

## [Unreleased]

## [1.1.3] - 2026-10-19

### Fixed

- Added an environment-profile launcher for native Flutter development that
  forwards only the five public App/API settings and preserves configured
  device addresses without platform-dependent rewriting.
- Unified native, container-build, and candidate-package configuration loading;
  explicitly empty API ports now retain the scheme's default port.
- Granted Android network access and limited local HTTP support to debug builds.
- Updated the container lifecycle test fixture to include required build-date
  metadata.

## [1.1.1] - 2026-10-13

### Added

- Added URL-addressable Profile and transaction-detail destinations with
  refresh, history, and source-context restoration.
- Added focused accessibility, light/dark theme, reduced-motion, large-text,
  responsive modal, and localized-period regression coverage.

### Changed

- Applied coherent semantic light and dark surfaces across authenticated,
  authentication, setup, dialog, sheet, toast, and empty/error states.
- Constrained add-transaction sheets to the 430 px mobile canvas on tablet and
  desktop hosts while retaining phone width, safe areas, and keyboard access.
- Localized Budget month labels through the same locale-aware period boundary
  used by Statistics while retaining canonical `YYYY-MM` API periods.
- Replaced persistent startup motion with a brief entrance and made startup and
  validation feedback honor reduced-motion preferences.

### Fixed

- Restored localized semantics for icon-only navigation and actions, auth
  inputs, and composite controls without duplicate announcements or actions.
- Preserved currency minor-unit precision when aggregating and presenting
  Budget totals, spent values, remaining values, and progress.

## [1.1.0] - 2026-10-12

### Changed

- Redesigned registration email verification around a clear read-only delivery
  destination, focused six-digit code entry, resend feedback, and localized
  Confirm and Return to edit email actions.

## [1.0.10] - 2026-10-12

### Changed

- Applied the selected currency symbol consistently across Home, Transactions,
  transaction entry and editing, Statistics, and Budget without converting
  stored values.
- Kept Currency, Theme, and Language preferences exclusively in Settings while
  retaining account identity, information, and statistics in Profile.

### Fixed

- Kept multi-character currency symbols responsive on compact finance surfaces.
- Removed preference persistence from Profile saves so editing account details
  cannot overwrite Settings-owned configuration.

## [1.0.9] - 2026-10-12

### Changed

- Adopted the approved English, Simplified Chinese, and Traditional Chinese
  CashLenX slogan across splash, authentication, and About surfaces.
- Split About identity into App Version, API Version, and artifact-generated
  UTC Build Date rows with readable loading, unavailable, and retry states.

### Fixed

- Constrained the About dialog to the mobile content viewport on wide screens
  while retaining scroll access on compact and large-text layouts.
- Preserved the selected dashboard range through scrolling, rebuilds, data
  refresh, and round trips to expanded Statistics.

## [1.0.8] - 2026-10-12

### Changed

- Promoted Transactions into the primary Home navigation while moving Category
  Management under Settings > Resource Management.
- Routed Home's recent-activity See All action to the same Transactions tab and
  kept the bottom navigation visible.
- Replaced the dashboard category chart with a compact Financial Insights entry
  that opens the expanded Statistics page.

### Fixed

- Reconciled authenticated cash flows with the user's category list so legacy
  API payloads still render current category icons, colors, and income direction
  across the dashboard, transaction list, and transaction detail.
- Replaced repository-text Chinese font subsets with pinned complete Simplified
  and Traditional Chinese fonts that are verified and loaded before `runApp`,
  including glyphs used only by dynamic API and user-provided text.

## [1.0.7] - 2026-10-10

### Added

- Added Day, Month, and Year controls to expanded statistics with matching
  period navigation, API-backed summaries, trends, and top expenses for real
  and Demo users.

### Fixed

- Kept the dashboard summary and category breakdown on one shared range and
  carried Day, Month, or Year into expanded statistics.
- Restored account-backed currency, language, theme, and setup completion
  before routing an existing user on a clean device.

## [1.0.6] - 2026-10-10

### Fixed

- Kept recent cash flows stable by business date and creation order, refreshed
  dashboard data after successful transaction creation, and displayed current
  category presentation and income direction consistently.
- Applied transaction filters before pagination and added page navigation with
  stale-response protection across authenticated and Demo data.
- Constrained the responsive Web avatar picker and clarified its edit action.
- Validated populated profile drafts before any write and omitted blank
  optional profile values while preserving stored values.

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
