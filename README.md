# CashLenX App

CashLenX is a modern, cross-platform finance application built with Flutter. It aims to provide a seamless experience for managing personal finances, tracking expenses, and planning budgets.

## 🚀 Features (Planned)
- **User Authentication**: Secure login and registration.
- **Dashboard**: Overview of financial health.
- **Transactions**: Add, edit, and categorize income and expenses.
- **Budgeting**: Set limits and track progress.
- **Reports**: Visual breakdown of spending habits.
- **Cross-Platform**: Runs on Android, iOS, Web, and Desktop.

## 🛠 Tech Stack
- **Framework**: [Flutter](https://flutter.dev/)
- **Language**: [Dart](https://dart.dev/)
- **State Management**: [Riverpod](https://riverpod.dev/) (with Code Generation)
- **Architecture**: Clean Architecture + Feature-First
- **Networking**: [Dio](https://pub.dev/packages/dio)
- **Routing**: [GoRouter](https://pub.dev/packages/go_router)
- **Dependency Injection**: [GetIt](https://pub.dev/packages/get_it) + [Injectable](https://pub.dev/packages/injectable)
- **Code Generation**: [Freezed](https://pub.dev/packages/freezed), [JsonSerializable](https://pub.dev/packages/json_serializable)

## 📂 Project Structure

We follow a **Feature-First** structure combined with **Clean Architecture**.

```
lib/
 ├─ core/           # Global utilities, configs, and exceptions
 ├─ network/        # Networking layer (Dio client, Interceptors)
 ├─ auth/           # Authentication domain
 ├─ features/       # Business modules (Splash, Login, Dashboard)
 │   └─ [feature]/
 │       ├─ data/          # API calls, DTOs, Repositories Impl
 │       ├─ domain/        # Entities, UseCases, Repository Interfaces
 │       └─ presentation/  # Widgets, Riverpod Providers, States
 ├─ shared/         # Reusable UI widgets
 ├─ routing/        # Navigation configuration
 ├─ theme/          # App theming
 └─ main.dart       # Entry point
```

## 🏁 Getting Started

### Prerequisites
- Flutter SDK (>=3.2.0)
- Dart SDK

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-org/cashlenx.git
    cd cashlenx/cashlenx-app
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Generate code (required):**
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
    *Tip: Use `watch` during development to auto-generate files on change:*
    ```bash
    dart run build_runner watch --delete-conflicting-outputs
    ```

4.  **Run the app:**
    ```bash
    flutter run
    ```

## 🧪 Testing

Run unit and widget tests:

```bash
flutter test
```

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
