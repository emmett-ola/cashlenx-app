# CashLenX Architecture & Development Guide

## 1. Project Structure
We follow a **Feature-First** structure combined with **Clean Architecture**. This ensures scalability and separation of concerns.

```
lib/
 ├─ core/           # Global utilities, configs, and exceptions (Low-level)
 │   ├─ config/     # Environment configurations (Dev, Prod)
 │   └─ constants/  # App-wide constants
 ├─ network/        # Networking layer (Dio client, Interceptors, Exceptions)
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

## 4. Networking Layer
Implemented in `lib/network/`.
- **Dio**: Powerful HTTP client.
- **ApiClient**: Wrapper to handle standard error mapping (`ApiException`).
- **Interceptors**: 
    - `LogInterceptor`: For debugging.
    - `AuthInterceptor` (Planned): To inject JWT tokens automatically.
- **Error Handling**: Centralized mapping of HTTP status codes to Domain Exceptions.

## 5. Environment & Configuration
Implemented in `lib/core/config/app_config.dart`.
- Supports `dev`, `staging`, `prod`.
- Uses static initialization in `main.dart`.
- Allows switching API endpoints and logging levels based on environment.

## 6. Platform Adaptation
- **GoRouter**: Handles deep linking and web URL routing natively.
- **Responsive Design**: We will use `LayoutBuilder` and flexible widgets in `shared/` to adapt to Desktop/Mobile.
