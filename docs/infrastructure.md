# Infrastructure Foundation

The reusable foundation lives under `lib/core/infrastructure/`. It contains app-agnostic contracts and adapters that can be reused by this app or copied into a new Flutter project.

## Modules

- `errors/`: shared exception types and error-message normalization.
- `http/`: REST client contract, Dio exception mapping, and request tracking.
- `logging/`: small `AppLogger` interface plus a `logger` package adapter.
- `persistence/`: `KeyValueStore` interface plus secure and in-memory implementations.
- `routing/`: pure redirect policy for auth-aware route protection.

Use `package:cashlenx/core/infrastructure/infrastructure.dart` as the barrel export when building new shared code.

## Design Rules

- Infrastructure code must not import business features.
- Feature data sources depend on interfaces or app adapters, not raw transport details where avoidable.
- UI code should not parse backend error payloads directly; use `ErrorMessageResolver` or `ToastUtils`.
- Persistence policy should live in service classes, while storage mechanics stay behind `KeyValueStore`.
- Routing decisions should be testable without Flutter widgets or GoRouter.
- Logging and request tracking must avoid secrets, tokens, and request bodies by default.

## HTTP

`RestClient` defines the minimal app-facing HTTP contract. `ApiClient` is the app adapter backed by Dio and maps transport failures through `DioExceptionMapper`.

`RequestTrackingInterceptor` adds an `x-request-id` header, records elapsed time, and logs request completion/failure through `AppLogger`. It intentionally does not log bodies.

## Persistence

`SecureStorageService` owns auth-token storage policy and delegates reads/writes to `KeyValueStore`. Production uses `SecureKeyValueStore`; tests can use `MemoryKeyValueStore`.

## Routing

`AuthRedirectPolicy` is a pure Dart policy that maps an auth status plus current location to a redirect path. `app_router.dart` adapts Riverpod auth state and GoRouter state into this policy.

## Testing

Infrastructure tests live under `test/core/` and cover:

- Dio error-to-exception mapping.
- Server error-message normalization.
- In-memory key-value persistence behavior.
- Auth redirect decisions.
- Request tracking metadata and logging.
- Secure-storage session clearing policy.
