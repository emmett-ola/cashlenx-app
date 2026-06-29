# Testing Strategy

This project uses a small test pyramid while the app is still in early auth and shell development.

## Current Commands

```bash
flutter analyze
flutter test
```

Run the live Flutter-to-server smoke flow on Windows with Docker available:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/smoke-api.ps1
```

The script starts disposable MongoDB and API instances, seeds purpose-scoped
signup/password-reset codes directly, and runs `integration_test/api_smoke_test.dart`
without sending email or retaining test data.

Both commands should pass before committing.

## What To Test

- Unit tests for pure Dart behavior: DTO parsing, repositories with fake data sources, storage policy, and small helpers.
- Infrastructure tests for HTTP error mapping, error-message resolution, request tracking, route redirect policy, and persistence adapters.
- Provider tests for auth state: initial logged-out state, remember-me refresh success, refresh failure, login success, login failure, logout, password-reset request, and password-reset confirm.
- Widget tests for routed auth flows: splash to login, login to register, login to forgot password, form validation, loading states, and success/error messages.
- Live integration coverage for registration, login, refresh, logout, profile,
  cash flow, category, statistics, XLSX import, CSV/XLSX export, backup,
  password reset, and admin APIs.

## Mocking Approach

- Prefer Riverpod provider overrides in tests instead of global mocks.
- Keep network tests behind fake repositories/data sources unless explicitly running integration checks against `../cashlenx-server`.
- Keep secure-storage behavior behind `secureStorageServiceProvider` overrides for auth-state tests.
- Do not make widget tests depend on a live API server.

## Required Local Files

`.env` is listed as a Flutter asset and is required for app startup. Use `sample.env` as the local template. Do not commit real secrets.
