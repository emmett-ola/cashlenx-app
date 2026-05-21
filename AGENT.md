# CashLenX Agent Notes

This file is the handoff point for future AI coding sessions in this repo. Read it before making changes.

## Project Snapshot

- App: CashLenX, a cross-platform Flutter finance app for personal finance, expense tracking, budgets, and reports.
- Current state: early development. Splash/pre-splash, login, registration, forgot-password, demo mode with app-side mock data, real auth request handling, auth persistence, silent refresh, authenticated home shell, settings theme color, profile page, Docker web deployment, and GitHub Actions web release publishing exist.
- Language/runtime: Dart SDK `>=3.2.0 <4.0.0`, Flutter.
- Architecture: feature-first Clean Architecture.
- State management: Riverpod with code generation (`riverpod_annotation`, generated `*.g.dart`).
- Routing: GoRouter.
- Networking: Dio through local wrappers and interceptors.
- Serialization: Freezed + json_serializable.
- Dependency injection packages are present (`get_it`, `injectable`) but the active code currently uses Riverpod providers.

## Related Repositories

This repo is one part of a three-repo local workspace:

- `../cashlenx-app`: this Flutter app.
- `../cashlenx-server`: Go API server built separately. Use it as the implementation source for API behavior when local app docs are stale.
- `../cashlenx-design`: Figma-exported React/Vite design reference. Use it as the visual/interaction reference before inventing new UI.

The app also includes a local API contract copy at `server/docs/openapi.yaml`. Cross-check this with `../cashlenx-server/docs/openapi.yaml` when backend behavior is uncertain.

## Current Branch

- Active development branch: `dev/v0.3.0`.
- Keep preparation and initial project setup work on this branch unless the user asks for another branch.
- After completing each user request, commit and push the completed work before ending the turn unless the user explicitly asks not to.

## Important Files

- `README.md`: project overview, setup, planned features.
- `docs/ARCHITECTURE.md`: architecture and development guide.
- `docs/infrastructure.md`: reusable infrastructure foundation guide.
- `docs/roadmap.md`: staged development plan for future implementation.
- `docs/testing.md`: current test/mocking strategy.
- `pubspec.yaml`: dependencies, assets, launcher icon config.
- `analysis_options.yaml`: lint rules.
- `sample.env`: environment template.
- `.env`: required by `AppConfig.init()` at runtime and listed as a Flutter asset. Do not commit real secrets.
- `Dockerfile`: multi-stage Flutter web build served by nginx on port `8080`.
- `compose.yml`: local/server Compose service for the web build. Uses `WEB_PORT`, `IMAGE_NAME`, and `IMAGE_TAG` from `.env` when present.
- `docker/nginx.conf`: nginx config for Flutter web history fallback.
- `.github/workflows/web-release.yml`: builds, analyzes, tests, and publishes web releases to `emmett-ola/cashlenx-app-release`.
- `server/docs/openapi.yaml`: local API contract reference.
- `lib/main.dart`: initializes `AppConfig`, `ProviderScope`, themes, and `MaterialApp.router`.
- `lib/routing/app_router.dart`: GoRouter setup and auth redirects.
- `lib/core/config/app_config.dart`: loads `.env` and builds `AppConfig.apiBaseUrl`.

## App Structure

Follow the existing feature-first layout:

- `lib/core/`: app-wide config, utilities, response wrappers, secure storage.
- `lib/core/infrastructure/`: reusable HTTP, routing, error, logging, and persistence contracts/adapters.
- `lib/network/`: app-specific Dio setup, API client adapter, and interceptors.
- `lib/features/<feature>/data/`: DTOs, remote data sources, repository implementations.
- `lib/features/<feature>/domain/`: entities/models and repository interfaces. Keep Flutter dependencies out of domain code.
- `lib/features/<feature>/presentation/`: pages, widgets, Riverpod providers/state.
- `lib/shared/`: reusable UI widgets.
- `lib/routing/`: GoRouter configuration.
- `lib/theme/`: app theme and theme mode provider.

Prefer adding new functionality inside the relevant feature folder instead of growing global folders.

## Implemented App Behavior

- Splash screen: `lib/features/splash/presentation/pages/splash_screen.dart`
  - Teal gradient, white logo, app name, slogan, pulse/entrance animation.
  - Web has a matching pre-splash in `web/index.html` that appears before Flutter/WASM is ready. This is static HTML/CSS/inline SVG, uses fixed brand colors, and intentionally does not follow user-picked theme color.
  - On web, the Flutter splash starts already visible to avoid a second entrance animation after WASM is ready. Native platforms keep the entrance animation.
  - Auth provider intentionally waits 2 seconds so the splash is visible.

- Login screen: `lib/features/auth/presentation/pages/login_page.dart`
  - Username-or-email field, password field, visibility toggle, remember-me checkbox, forgot-password link, demo-mode action, sign-up link.
  - Calls real backend login through `AuthNotifier.login(...)`.
  - Shows server errors using `ToastUtils.showServerErrors(...)`.
  - Shows a success toast on successful manual login.

- Registration screen: `lib/features/auth/presentation/pages/register_page.dart`
  - Email, password, confirm-password fields, validation, and real backend registration through `AuthNotifier.register(...)`.
  - Successful registration returns the user to login.

- Forgot password screen: `lib/features/auth/presentation/pages/forgot_password_page.dart`
  - Requests reset token through `/open/auth/reset-password`.
  - Confirms token and new password through `/open/auth/reset-password/confirm`.

- Auth state: `lib/features/auth/presentation/providers/auth_provider.dart`
  - `AuthNotifier` is `keepAlive`.
  - On app start, it checks `SecureStorageService.getRememberMe()`.
  - If remember-me is false, it clears stored auth data and treats the user as logged out.
  - If remember-me is true and a refresh token exists, it calls refresh-token login.
  - Failed refresh clears storage and returns logged out.
  - `continueAsDemo()` resets `DemoDataStore` every time the user enters demo mode from the login page. Demo mode must not call authenticated backend APIs.

- Auth persistence: `lib/core/services/secure_storage_service.dart`
  - Stores `auth_token`, `auth_refresh_token`, and `auth_remember_me` with `flutter_secure_storage`.
  - `clearSession()` removes tokens only.
  - `clearAll()` removes tokens and remember-me state.

- Routing: `lib/routing/app_router.dart`
  - Routes: `/` splash, `/login`, `/register`, `/forgot-password`, `/home`, `/profile`.
  - Logged-in users on splash/login/register/forgot-password redirect to `/home`.
  - Logged-out users redirect to `/login` after splash/loading.
  - `/home` hosts the first authenticated app shell.

- Home/app shell: `lib/features/home/presentation/pages/home_page.dart`
  - Replaces the old temporary welcome page.
  - Uses a bottom navigation shell based on `../cashlenx-design/src/components/organisms/BottomNav.tsx`.
  - Includes Home, Stats, Add, Budget, and Settings tabs.
  - Demo mode uses `lib/features/demo/data/demo_data_store.dart` for app-side dashboard/category data and resets that data on each demo entry.
  - Non-wired interactions show a "coming soon" toast.
  - Dashboard avatar and Settings profile card navigate to `/profile`.
  - Settings logout calls `AuthNotifier.logout()`.
  - Settings Theme Color persists through `themeColorProvider` in `lib/theme/app_theme.dart`; it changes in-app primary/accent usage but not the splash/pre-splash.

- Profile page: `lib/features/profile/presentation/pages/profile_page.dart`
  - Uses `GET /user/profile` and `PUT /user/profile` through `CashlenxApi`.
  - Persists the API-supported fields only: `nickname`, `avatar_url`, and `gender`; username/email/status/role/date fields are read-only.
  - Demo profile uses local static data and does not request the API.

- Shared UI:
  - Toasts are centralized in `ToastUtils`; use `showSuccess`, `showError`, `showInfo`, or `showServerErrors` instead of custom SnackBars.
  - Reusable surface/list/panel widgets live in `lib/shared/widgets/app_surface.dart`.
  - Reusable color picker widgets live in `lib/shared/widgets/app_color_picker.dart`.
  - Keep app icon sources in `assets/images/app_icon.png` and `assets/images/app_icon_foreground.png`; platform icons were unified from those assets. Future holiday icon replacement should start from these source assets/config, not manual platform edits.

## Backend/API Integration

- API base URL is built from `.env`:
  - `API_SCHEME`, `API_DOMAIN`, `API_PORT`, `API_VERSION`.
  - `sample.env` points to `http://localhost:10063/api/v0`.
- All HTTP should go through `ApiClient` and `dioProvider`.
- Feature code can call `CashlenxApi` from `lib/network/cashlenx_api.dart` for ready-to-use methods covering the current `server/docs/openapi.yaml` contract. Prefer adding feature-specific parsing/repositories around those methods instead of duplicating endpoint paths.
- Shared infrastructure contracts are exported from `lib/core/infrastructure/infrastructure.dart`.
- `AuthInterceptor` injects `Authorization: Bearer <token>` when a token exists.
- `AuthInterceptor` attempts one silent refresh on 401/UNAUTHORIZED when remember-me is enabled and a refresh token exists, then retries the failed request.
- `RequestTrackingInterceptor` adds `x-request-id` and logs method/path/status/timing without request or response bodies.
- `ResponseWrapper<T>` matches the server wrapper shape: `code`, `message`, `data`, `meta`, `errors`, `extra`.
- `ToastUtils.showServerErrors(...)` expects backend errors such as `{"errors":[{"message":"..."}]}`.

## Web Build and Release

- Local/server container deployment uses `compose.yml`:

```bash
docker compose up -d --build
```

- The Compose service is `cashlenx-web`, builds from `Dockerfile`, and exposes container port `8080` as `${WEB_PORT:-8080}` on the host.
- The Docker image builds Flutter web with `flutter build web --release`, then serves `build/web` with nginx.
- `docker/nginx.conf` uses `try_files $uri $uri/ /index.html` so Flutter web routes work on refresh/deep links.
- `.env` is copied into the Docker image and loaded by Compose through `env_file`; keep real secrets out of commits.
- GitHub Actions workflow `.github/workflows/web-release.yml` runs on pushes to `main`, pushes to `dev/**`, and manual dispatch.
- The workflow creates `.env` from repository/environment variables, runs `flutter pub get`, code generation, `flutter analyze`, `flutter test`, and `flutter build web --release`.
- Web release output is published to external repo `emmett-ola/cashlenx-app-release`: source branch `main` publishes to release branch `main`; all `dev/**` branches publish to release branch `develop`.

Auth endpoints currently used:

- `POST /open/auth/login`
  - Username/password login body: `{ "username": "...", "password": "..." }`
  - Refresh login body: `{ "refresh_token": "..." }`
  - Server returns wrapped data containing `access_token`, `refresh_token`, and `user`.
  - Verified against the current `../cashlenx-server/controller/auth_controller/auth.go`, `../cashlenx-server/model/refresh_token.go`, and `../cashlenx-server/docs/openapi.yaml`.
- `POST /open/auth/register`
  - Registration page is wired and uses email as username.
- `POST /open/auth/logout`
  - Repository logout sends the stored refresh token when available to revoke the current session, then clears local session tokens.
- `POST /open/auth/reset-password`
  - Forgot-password request flow.
- `POST /open/auth/reset-password/confirm`
  - Forgot-password confirm flow.
- `GET /user/profile`
  - Used by `getCurrentUser()` when a token exists, but startup usually prefers refresh-token login if remember-me is enabled.
- `PUT /user/profile`
  - Used by the Profile page to update `nickname`, `avatar_url`, and `gender`.

Profile API gaps versus `../cashlenx-design/src/app/components/screens/Profile.tsx`:

- No persisted phone number.
- No persisted location.
- No persisted birth date.
- No persisted preferred currency.
- No avatar upload or avatar preset endpoint; only `avatar_url` can be saved.
- No profile/account statistics endpoint for transaction count, active budgets, months active, or saved amount.

## Design Reference

Use `../cashlenx-design` as the source of truth before changing UI. Match the design reference as closely as practical for Material component sizes, border radii, spacing, and overall layout rather than guessing from Flutter defaults. Useful files:

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
- Accent/coral in design reference: `#FF8A65`
- Design reference uses a clean mobile-first finance-app layout. Match exact component geometry from the relevant reference file when it is visible there; for example auth primary/demo buttons are tall pill-style controls (`48px` height with a fully rounded radius in the Flutter app).

Flutter auth screens should stay aligned with the `AuthLayout`, `Login`, and `SignUp` design reference. The selected splash/auth subtitle is `Your Financial Companion`.

The splash/pre-splash should remain brand-stable using `#008080` and `#4DB6AC`; do not bind it to the user-picked theme color unless the user explicitly changes that preference.

## Known Gaps / Next Likely Work

- Dashboard/home still needs full real API integration for non-demo users beyond the currently wired summary/category surfaces.
- Transactions and add-transaction flows are still placeholders/coming-soon interactions.
- Auth tests are still light. Add provider tests with Riverpod overrides for login, register, reset, refresh, and logout behavior.
- Profile is implemented, but backend support is narrower than the design reference. Add the missing profile fields/endpoints above before expanding the UI.
- Some README/architecture text is aspirational and may not match current code exactly.

## Generated Files

The repo contains generated Dart files:

- `*.g.dart`
- `*.freezed.dart`

Do not hand-edit generated files. Edit the source files and regenerate with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Use watch mode during longer development sessions:

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

Run the app:

```bash
flutter run
```

Run the API server locally from the sibling repo when needed:

```bash
cd ../cashlenx-server
go run main.go server start -p 10063
```

Run the design reference locally when needed:

```bash
cd ../cashlenx-design
npm install
npm run dev
```

## Development Rules

- Preserve Clean Architecture dependency direction: presentation -> domain contracts -> data implementations.
- Keep domain models and business logic pure Dart where possible.
- Use Riverpod annotation/codegen patterns that already exist in the repo.
- Use Dio through the existing networking layer instead of creating ad hoc HTTP clients.
- Keep API parsing aligned with `ResponseWrapper<T>` and the OpenAPI/server contract.
- Keep UI consistent with `../cashlenx-design`, `AppTheme`, and existing shared widgets before adding new styling patterns.
- Prefer small, focused changes and verify with `dart analyze`/`flutter analyze` on touched files plus relevant tests. Avoid `flutter build` on this machine unless the user explicitly asks; it is too heavy.
- Running `flutter test` may rewrite `pubspec.lock` package hosts. Restore unrelated lockfile churn before committing.
- Do not commit `.env` or local secrets. Use `sample.env` for documented variables.
- Avoid unrelated platform-folder edits unless the task explicitly needs Android/iOS/web/desktop changes.
- If a generated file changes, mention the source file that caused it.

## Session Memory

- Initial collaboration branch `dev/init` was created from `main`.
- The first preparation task was to add this `AGENT.md` file for future sessions.
- This file was expanded after reviewing the app, the local OpenAPI copy, `../cashlenx-server`, and `../cashlenx-design`.
