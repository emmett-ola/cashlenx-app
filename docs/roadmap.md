# CashLenX App Roadmap

This roadmap is the working development plan for the Flutter app. It should evolve as the app, server, and design reference evolve.

## Current Baseline

Implemented:

- Flutter app scaffold with feature-first Clean Architecture.
- App config from `.env`.
- Riverpod, GoRouter, Dio, Freezed/json_serializable setup.
- Splash screen with logo animation.
- Login screen connected to the real CashLenX server auth endpoint.
- Registration screen connected to the real CashLenX server auth endpoint.
- Auth response parsing for `access_token`, `refresh_token`, and `user`.
- Error notifications for server validation/API errors.
- Remember-me based startup login through refresh token.
- Demo mode route into the authenticated home shell.
- Logout calls the backend logout endpoint when a refresh token is available, then clears the local session.
- First `/home` app shell with fixed mock dashboard, stats, budget, add placeholder, settings, and bottom navigation.
- Docker-based Flutter web deployment using `Dockerfile`, `compose.yml`, and nginx route fallback.
- GitHub Actions web release workflow that builds, analyzes, tests, and publishes static web output to the release repo.
- `flutter analyze` and `flutter test` are clean.
- A disposable MongoDB-backed Flutter integration smoke test covers the active `/api/v0` client contract.

Known gaps:

- Dashboard/home uses fixed mock data and is not connected to real statistic/cash-flow APIs yet.
- Transactions and add-transaction flows are still coming-soon placeholders.
- Auth provider/repository test coverage is still lighter than the UI smoke path.

## Guiding Principles

- Build in small, verifiable steps.
- Keep API behavior aligned with `../cashlenx-server` and its OpenAPI docs.
- Use `../cashlenx-design` as the visual reference before creating new UI patterns.
- Keep feature code inside `lib/features/<feature>/`.
- Prefer complete vertical slices: domain model, data source, repository, provider, UI, and basic tests.

## Phase 1: Project Foundation

Goal: make the app easier to run, verify, and extend before adding larger finance features.

- Finalize root documentation layout.
- Keep `README.md` as the entry point and `AGENT.md` as the AI collaboration handoff.
- Keep detailed docs in `docs/`.
- [x] Verify `.env` setup and document local server assumptions.
- [x] Add basic test/mocking strategy for config, routing, and auth state.
- [x] Run and fix `flutter analyze`.
- [x] Review generated files and ensure source/generation workflow is clean.
- [x] Extract reusable infrastructure contracts for HTTP, routing, errors, logging, and persistence.

Exit criteria:

- A new developer or agent can read `README.md`, `AGENT.md`, and `docs/roadmap.md` and continue without rediscovery.
- `flutter analyze` is clean or known issues are documented.

## Phase 2: Authentication Completion

Goal: turn the current login flow into a complete auth module.

- [x] Wire backend logout through `POST /open/auth/logout`.
- [x] Decide expected logout behavior for remember-me: app logout revokes the current refresh token when available, then clears local session tokens while keeping the remember-me preference.
- [x] Implement registration screen using existing `AuthRepository.register`.
- [x] Add forgot-password request/confirm flows if supported by the server.
- [x] Add authenticated profile fetch/update if needed for account setup. Current profile fetch is used for token-backed startup state; profile update is deferred until profile/settings scope.
- [x] Add silent refresh for 401 responses or define why startup-only refresh is enough for now.
- [x] Replace simulated registration verification with the purpose-scoped verification API and pass the returned token to registration.
- [x] Verify password-reset email codes before submitting the returned reset token.
- [x] Add a live Flutter API smoke flow covering auth and core finance/admin APIs without sending email.
- Improve auth provider tests around login success, login failure, remember-me startup, refresh failure, and logout.

Exit criteria:

- A user can register, login, stay logged in when remember-me is enabled, logout intentionally, and recover from common auth errors.

## Phase 3: App Shell and Navigation

Goal: replace temporary `/home` with the real authenticated app frame.

- Build the main app shell from the design reference.
- Add bottom navigation or equivalent responsive navigation.
- Define top-level routes for dashboard, transactions, add transaction, budgets/categories, stats, and settings/profile.
- Preserve auth redirect behavior across web/mobile/deep links.
- Add loading and empty states for authenticated pages.

Progress:

- [x] Replaced temporary `/home` welcome screen with a first authenticated shell.
- [x] Added bottom navigation for Home, Stats, Add, Budget, and Settings.
- [x] Added fixed mock dashboard data behind a mock request provider.
- [x] Kept unwired interactions as coming-soon toasts.
- [ ] Connect transactions/add/profile/category flows to real screens.
- [ ] Decide whether shell tabs should become URL-addressable routes.

Exit criteria:

- Login lands in a real app shell.
- Navigation structure matches the design direction and can host future finance features.

## Phase 4: Dashboard

Goal: implement the first useful finance overview screen.

- Define dashboard data models from server statistic/dashboard endpoints.
- Add dashboard data source, repository, providers, and UI.
- Show total balance/summary, income/expense overview, recent transactions, and useful empty state.
- Add loading, error, and retry behavior.
- Add basic widget/provider tests for dashboard states.

Exit criteria:

- Authenticated users can see a meaningful dashboard populated from real or documented API data.

## Phase 5: Transactions

Goal: allow users to view and manage cash flow records.

- Implement transaction list with filters/date ranges.
- Implement add income/expense flow.
- Implement edit/delete flows.
- Integrate categories.
- Add validation and server error handling.
- Add optimistic or explicit refresh behavior after mutations.

Exit criteria:

- A user can create, view, edit, and delete income/expense transactions through real API calls.

## Phase 6: Categories and Budgeting

Goal: provide the organization layer needed for useful finance tracking.

- Implement category list/tree UI.
- Add category create/edit/delete where supported.
- Connect categories into transaction creation.
- Implement budget screens after confirming backend support and design scope.

Exit criteria:

- Transactions can be categorized through app-managed categories.
- Budgeting has a clear, tested first version or a documented dependency on server work.

## Phase 7: Reports and Statistics

Goal: expose spending insight screens.

- Implement statistics summary, trends, breakdown, and top-expense screens.
- Add date/period controls.
- Add charts using a Flutter charting package only after evaluating project fit.
- Add export/import UI only after confirming server endpoints and product priority.

Exit criteria:

- Users can inspect spending patterns by period and category.

## Phase 8: Polish, Platform, and Release Readiness

Goal: make the app reliable across target platforms.

- Improve responsive layouts for mobile, web, and desktop.
- Review accessibility: labels, contrast, tap targets, keyboard navigation.
- Add app-wide error boundaries and retry patterns.
- Harden secure storage and token lifecycle behavior per platform.
- Add integration tests for auth and key finance workflows.
- Review app icons, web manifest, metadata, and release build settings.
- Keep Docker web deployment and GitHub Actions release docs aligned with workflow changes.

Exit criteria:

- Core workflows are tested, stable, and ready for a first internal release.

## Open Product Questions

- Should login accept username only, email only, or both?
- What should the final splash subtitle be: `Your Financial Companion` or `Your Money, Simplified`?
- What should remember-me mean exactly: refresh for 30 days, server refresh-token expiry, or another period?
- Should logout revoke only the current device's refresh token or all sessions by default?
- Should demo mode use local seeded data, a server demo account, or be removed until later?
- Which target platform should drive UI decisions first: mobile, web, or equal priority?

## Maintenance Notes

- Update this roadmap when a phase is completed or priorities change.
- Add links to implementation PRs/commits when meaningful.
- Keep roadmap items actionable; move detailed design notes into separate docs if they grow large.
