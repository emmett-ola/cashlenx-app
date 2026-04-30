# CashLenX Architecture & Development Guide

## 1. Project Structure
We follow a **Feature-First** structure combined with **Clean Architecture**. This ensures scalability and separation of concerns.

```
lib/
 ├─ core/           # Global utilities, config, and reusable infrastructure
 │   ├─ config/     # Environment configuration
 │   ├─ infrastructure/
 │   │   ├─ errors/       # Exception taxonomy and error-message normalization
 │   │   ├─ http/         # REST contract, Dio mapping, request tracking
 │   │   ├─ logging/      # AppLogger contract and adapters
 │   │   ├─ persistence/  # Key-value storage contracts and adapters
 │   │   └─ routing/      # Pure route redirect policies
 │   └─ services/   # App services built on infrastructure contracts
 ├─ network/        # App-specific HTTP composition and Dio adapters
 ├─ auth/           # Authentication domain (User session, Tokens)
 ├─ features/       # Business modules (Splash, Login, Dashboard)
 │   └─ [feature]/  # Inside each feature:
 │       ├─ data/          # API calls, DTOs, Repositories Impl
 │       ├─ domain/        # Entities, UseCases, Repository Interfaces
 │       └─ presentation/  # Widgets, Riverpod Providers, States
 ├─ shared/         # Reusable UI widgets (Buttons, Inputs)
 ├─ routing/        # Navigation configuration (GoRouter)
 ├─ theme/          # App theming (Light/Dark mode)
 ├─ state/          # Global application state (if not feature-specific)
 └─ main.dart       # Entry point
```

### Justification
- **Feature-first**: Allows multiple developers to work on different features without conflict. Scales indefinitely.
- **Clean Architecture (Data/Domain/Presentation)**:
    - **Domain**: Pure Dart code, no Flutter dependencies. Contains business logic.
    - **Data**: Handles external data sources (API, DB).
    - **Presentation**: UI and State management.

## 2. Architecture Pattern
We use **Riverpod + Clean Architecture**.

- **Data Flow**: `UI` -> `Controller/Provider` -> `UseCase` -> `Repository` -> `DataSource` -> `API`.
- **Dependency Direction**: Outer layers depend on inner layers. Domain depends on nothing.
- **Testing**:
    - **Unit Tests**: For UseCases and Repositories (Mocking DataSources).
    - **Widget Tests**: For UI components.
    - **Integration Tests**: For critical flows.

## 3. State Management: Riverpod
Selected **Riverpod** (with Code Generation) because:
- **Compile-safe**: Catches provider errors at compile time.
- **No Context**: specific logic doesn't need `BuildContext`, making it easier to test and use in pure logic classes.
- **Caching/Auto-dispose**: Built-in support for caching API responses and disposing unused state.

## 4. Infrastructure Layer
Reusable foundation code is in `lib/core/infrastructure/` and is intentionally decoupled from business features.

- **Errors**: `ApiException` taxonomy and `ErrorMessageResolver`.
- **HTTP**: `RestClient` contract, Dio exception mapping, and request tracking.
- **Logging**: `AppLogger` interface plus adapters.
- **Persistence**: `KeyValueStore` interface, secure storage adapter, and memory adapter for tests.
- **Routing**: pure `AuthRedirectPolicy` used by the app router.

App-specific composition remains in `lib/network/`, `lib/routing/`, and feature folders. This keeps infrastructure reusable without forcing feature code into global modules.

## 5. Networking Layer
Implemented through infrastructure contracts and app adapters.

- **Dio**: concrete HTTP engine.
- **ApiClient**: app `RestClient` adapter backed by Dio.
- **AuthInterceptor**: injects JWT tokens and attempts one silent refresh/retry for eligible 401 responses.
- **RequestTrackingInterceptor**: adds request IDs and logs timing/status without logging secrets or bodies.
- **Error Handling**: `DioExceptionMapper` maps transport errors to the shared exception taxonomy.

## 6. Environment & Configuration
Implemented in `lib/core/config/app_config.dart`.
- Supports `dev`, `staging`, `prod`.
- Uses static initialization in `main.dart`.
- Allows switching API endpoints and logging levels based on environment.

## 7. Platform Adaptation
- **GoRouter**: Handles deep linking and web URL routing natively.
- **Responsive Design**: We will use `LayoutBuilder` and flexible widgets in `shared/` to adapt to Desktop/Mobile.
