# CashLenX Agent Notes

This file is the handoff point for future AI coding sessions in this repo.
Read it before making changes.

## Project Snapshot

- App: CashLenX, a cross-platform Flutter personal-finance app for expenses,
  income, budgets, categories, profile settings, and reports.
- Current branch: `develop`.
- Runtime: Flutter with Dart SDK `>=3.8.0 <4.0.0`.
- Architecture: feature-first Clean Architecture with Riverpod for state.
- Routing: GoRouter.
- Networking: Dio through local API wrappers and interceptors.
- Serialization: Freezed + json_serializable.
- Dependency injection packages are present, but active app code mainly uses
  Riverpod providers.

## Workspace References

This repo is part of a three-repo local workspace:

- `../cashlenx-app`: this Flutter app.
- `../cashlenx-server`: Go API server. Use it as the implementation source when
  local app docs are stale.
- `../cashlenx-design`: Figma-exported React/Vite design reference. Check it
  before changing UI geometry, behavior, or visual style.

The app also keeps a local API contract copy at `server/docs/openapi.yaml`.
Cross-check it with `../cashlenx-server/docs/openapi.yaml` when backend behavior
is uncertain.

## Important Files

- `pubspec.yaml`: dependencies, assets, launcher icon config.
- `analysis_options.yaml`: lint rules.
- `.env.example`: environment template.
- `.env`: selected by lifecycle scripts for local public build and Docker
  settings. It is never a Flutter asset or image-build context input. Do not
  commit real secrets.
- `lib/main.dart`: initializes config, provider scope, themes, i18n, and router.
- `lib/routing/app_router.dart`: GoRouter setup and auth redirects.
- `lib/core/i18n/app_i18n.dart`: app translations and language provider.
- `lib/core/config/app_config.dart`: loads `.env` and builds API base URL.
- `lib/network/cashlenx_api.dart`: ready-to-use API adapter methods.
- `lib/features/home/presentation/pages/home_page.dart`: authenticated shell,
  dashboard, settings, add/edit transaction UI, category and date selectors.
- `lib/features/profile/presentation/pages/profile_page.dart`: profile page and
  avatar/currency controls.
- `lib/features/demo/data/demo_data_store.dart`: editable demo-mode data store.
- `lib/theme/app_theme.dart`: theme mode and theme color providers.
- `lib/shared/widgets/app_surface.dart`: shared panels, cards, list tiles.
- `lib/shared/widgets/app_color_picker.dart`: shared color picker UI.
- `assets/images/avatars/`: fixed preset avatar image library.

## App Structure

Follow the existing feature-first layout:

- `lib/core/`: app-wide config, utilities, response wrappers, secure storage.
- `lib/core/infrastructure/`: reusable HTTP, routing, error, logging, and
  persistence contracts/adapters.
- `lib/network/`: app-specific Dio setup, API client adapter, and interceptors.
- `lib/features/<feature>/data/`: DTOs, remote data sources, repository
  implementations.
- `lib/features/<feature>/domain/`: entities/models and repository interfaces.
  Keep Flutter dependencies out of domain code.
- `lib/features/<feature>/presentation/`: pages, widgets, Riverpod providers.
- `lib/shared/`: reusable UI widgets.
- `lib/routing/`: GoRouter configuration.
- `lib/theme/`: app theme and theme mode providers.

Prefer adding new functionality inside the relevant feature folder instead of
growing global folders.

## Current App Behavior

- Splash and auth flows exist for login, registration, password reset, and demo
  mode.
- Auth persistence uses `SecureStorageService` for access token, refresh token,
  and remember-me state.
- Session writes persist the rotating refresh credential before the access
  token and clear both values if a partial write fails. Remembered startup
  restores only a complete refresh-backed session; malformed or partial state
  fails signed out.
- `AuthInterceptor` injects bearer tokens, serializes concurrent eligible 401
  refreshes, retries stale requests with an already-rotated access token, and
  never restores a session cleared during logout. Rejected refresh credentials
  expire the session; transient transport failures keep it for a later retry.
- Demo mode resets `DemoDataStore` every time the user chooses demo mode from
  login and clears real session credentials first. After entry, demo categories
  and transactions are editable during that session.
- Home shell has Home, Category, Add, Budget, and Settings tabs.
- Dashboard data uses the real API for normal users and `DemoDataStore` for demo
  users.
- Add Transaction and Edit Transaction share the same design language for amount
  display/keypad, category selection, date selection, description, remark, and
  attachments placeholder.
- Category selection supports hierarchical categories. Selecting a parent
  highlights it and opens its children; clicking the active parent can return to
  the previous level. Add/Edit remember the last selected category separately for
  income and expense while toggling transaction type.
- Required form fields use red validation text, highlighted containers, and a
  shake animation.
- Date display and inline calendar labels use Flutter localizations so language
  and region control date format, month title, weekday labels, and first day of
  week.
- Settings includes theme color, currency, language, about, and logout.
- Theme color persists through `themeColorProvider` and should drive primary
  buttons, accents, selected states, and highlights. Splash/pre-splash stays
  brand-stable unless the user explicitly asks otherwise.
- Profile uses `GET /user/profile` and `PUT /user/profile`. It currently saves
  API-supported fields: `nickname`, `avatar_url`, and `gender`.
- Profile currency preference is app-local through `currencyProvider`; backend
  does not currently persist preferred currency.
- Avatars are fixed presets from `assets/images/avatars/`. User-uploaded avatars
  are intentionally not planned. The app saves the selected preset asset path in
  `avatar_url`. If no avatar is set or loading fails, use
  `assets/images/avatars/f9b59ca5421b2b7ef2e31c2ba4d827f48d22594a.png`.

## Backend/API Integration

- API base URL is built from compile-time definitions populated by the
  container build script from the selected environment file:
  `API_SCHEME`, `API_DOMAIN`, `API_PORT`, `API_VERSION`.
- `.env.example` points to the canonical `http://127.0.0.1:10063/api/v1`; the Server owns the temporary `/api/v0` previous-client alias.
- All HTTP should go through `ApiClient`, `dioProvider`, and `CashlenxApi`.
- Keep API parsing aligned with `ResponseWrapper<T>` and the OpenAPI/server
  contract.
- `ToastUtils.showServerErrors(...)` expects backend errors such as
  `{"errors":[{"message":"..."}]}`.

Auth/profile endpoints currently used:

- `POST /open/auth/login`
- `POST /open/auth/register`
- `POST /open/auth/logout`
- `POST /open/auth/reset-password`
- `POST /open/auth/reset-password/confirm`
- `GET /user/profile`
- `PUT /user/profile`

Transaction/category/dashboard endpoints are wrapped in `CashlenxApi` and used
by the home shell where implemented. Demo mode must not call authenticated
backend APIs.

## Design Reference

Use `../cashlenx-design` as the source of truth before changing UI. Match the
design reference as closely as practical for component sizes, border radii,
spacing, and interactions instead of relying on Flutter defaults.

Useful design files:

- `src/components/screens/SplashScreen.tsx`
- `src/components/screens/Login.tsx`
- `src/components/screens/HomeScreen.tsx`
- `src/components/screens/Dashboard.tsx`
- `src/components/screens/AddTransaction.tsx`
- `src/components/screens/Transactions.tsx`
- `src/components/screens/Budget.tsx`
- `src/components/screens/Stats.tsx`
- `src/components/screens/Settings.tsx`
- `src/components/screens/Profile.tsx`
- `src/components/atoms/*`
- `src/components/molecules/*`
- `src/constants/colors.ts`

Current visual tokens from design:

- Primary teal: `#008080`
- Secondary/light teal: `#4DB6AC`
- Accent/coral: `#FF8A65`

The app is mobile-first. The Windows runner default size is set to an iPad
portrait-like window (`768x1024`) for local desktop testing.

## Generated Files

The repo contains generated Dart files:

- `*.g.dart`
- `*.freezed.dart`

Do not hand-edit generated files. Edit source files and regenerate with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Use watch mode during longer generated-code sessions:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Standard Commands

Install dependencies:

```bash
flutter pub get
```

Analyze:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

This repository currently has no maintained live Flutter-to-server integration
harness. Use the server repository's focused API smoke checks for backend
integration and validate complete journeys in the test environment.

Run targeted tests:

```bash
flutter test test/features/home/presentation/pages/home_page_test.dart
flutter test test/features/profile/presentation/pages/profile_page_test.dart
```

Run the app:

```bash
flutter run
```

Run the API server locally from the sibling repo when needed:

```bash
cd ../cashlenx-server
go run main.go open start -p 10063
```

Run the design reference locally when needed:

```bash
cd ../cashlenx-design
npm install
npm run dev
```

## Development Rules

- Preserve Clean Architecture dependency direction: presentation -> domain
  contracts -> data implementations.
- Keep domain models and business logic pure Dart where possible.
- Use the Riverpod patterns already present in the repo.
- Use Dio through the existing networking layer instead of creating ad hoc HTTP
  clients.
- Keep API parsing aligned with `ResponseWrapper<T>` and the server/OpenAPI
  contract.
- Keep UI consistent with `../cashlenx-design`, `AppTheme`, and shared widgets
  before adding new styling patterns.
- Prefer small, focused changes with relevant tests.
- Avoid `flutter build` on this machine unless the user explicitly asks; it is
  comparatively heavy.
- Running `flutter test` may rewrite `pubspec.lock` package hosts. Restore
  unrelated lockfile churn before committing.
- Do not commit `.env` or local secrets. `.env.example` keeps every documented
  assignment active so operators change values directly rather than uncommenting
  configuration lines.
- Flutter Web configuration is public. Keep it limited to `APP_ENV`,
  `API_SCHEME`, `API_DOMAIN`, `API_PORT`, and `API_VERSION`; never compile a
  credential into the client.
- Avoid unrelated platform-folder edits unless the task explicitly needs
  Android/iOS/web/desktop changes.
- If a generated file changes, mention the source file that caused it.
- Keep non-i18n code and comments ASCII-only unless the file already requires a
  different character set. Translation text belongs in `app_i18n.dart`.

## Web Build and Release

- Local/server container deployment uses `docker/compose.yml` through the
  lifecycle scripts:

```bash
scripts/build.sh
scripts/start.sh
```

- The Compose service is `cashlenx-web`, builds from `docker/Dockerfile`, and
  exposes container port `8080` as `${WEB_PORT:-10064}` on the host.
- Compose project, container, and external-network names are explicit
  environment values with defaults. App uses `APP_PROJECT_NAME` and
  `CONTAINER_NAME`; every repository uses the same absolute
  `DOCKER_NETWORK_NAME`. Start creates the network when absent; stop removes it
  only when no container remains connected.
- `docker/nginx.conf` uses `try_files $uri $uri/ /index.html` for Flutter web
  history fallback.
- `.github/workflows/ci.yml` runs analyze, tests, and the canonical `/api/v1`
  web build. Manual dispatch also packages an untagged, secret-free candidate
  image; publication and deployment remain separate release-gate actions.

## Known Gaps

- Some Profile fields in the design reference are not backend-persisted yet:
  phone number, location, birth date, preferred currency, and profile stats.
- Avatar selection should be implemented as a fixed preset picker using
  `assets/images/avatars/`, not file upload.
- Dashboard/statistics/budget surfaces still need continued real API coverage
  and deeper tests.
- Some README/architecture text may still be aspirational; prefer current code,
  server implementation, and OpenAPI when they disagree.
