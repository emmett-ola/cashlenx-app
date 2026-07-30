# CashLenX App

CashLenX is a modern, cross-platform finance application built with Flutter. It aims to provide a seamless experience for managing personal finances, tracking expenses, and planning budgets.

## 🚀 Current Features
- **Authentication**: Login, verified registration, password reset,
  refresh-token sessions, logout, and editable profile.
- **Dashboard**: Real summaries and recent transactions for authenticated
  users, with an isolated editable demo mode.
- **Transactions**: List, filter, create, edit, and delete income and expenses.
- **Categories**: User-scoped hierarchical category management.
- **Settings**: Theme color, currency, language, avatar preset, and profile.
- **Cross-Platform**: Flutter targets Android, iOS, web, and desktop.

Budget editing and the full reports/statistics experience remain roadmap work.

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
- Flutter/Dart SDK compatible with Dart `>=3.8.0 <4.0.0`
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

3.  **Create local configuration:**
    ```bash
    cp .env.sample .env
    ```

4.  **Generate code (required):**
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
    *Tip: Use `watch` during development to auto-generate files on change:*
    ```bash
    dart run build_runner watch --delete-conflicting-outputs
    ```

5.  **Run the app:**
    ```bash
    flutter run
    ```

## 🐳 Container Usage

Build and run the Flutter web app with the deployment scripts:

```bash
scripts/build.sh
scripts/start.sh
```

`build.sh` builds the image. `start.sh` replaces the running container from that
image without running `docker compose down`, then waits for the HTTP health
check. Run `scripts/health.sh` independently to check the deployed container.

Compose reads `compose.yml`. The container serves the built web app on internal
port `8080`, and by default Compose exposes it on host port `8080`:

```text
http://SERVER_IP:8080
```

To use a different host port, set `WEB_PORT` in `.env`:

```env
WEB_PORT=3000
```

The image name and tag can also be configured from `.env`:

```env
IMAGE_NAME=cashlenx-web
IMAGE_TAG=latest
```

Published ports bind to `127.0.0.1` by default for a host reverse proxy. The
sample environment also exposes CPU, memory, PID, graceful-stop, health-check,
and build-image settings. Each image records the source revision in the OCI
`org.opencontainers.image.revision` label.

Then rebuild and restart the service:

```bash
scripts/build.sh
scripts/start.sh
```

The Docker image performs a release Flutter web build and serves `build/web`
with nginx. The nginx config lives at `docker/nginx.conf` and falls back to
`index.html` for client-side routes.

For an external nginx reverse proxy, point the upstream to the exposed host
port, for example:

```text
127.0.0.1:8080
```

The `.env` file is included in both the Docker build context and the running
container via Compose `env_file`.

## 🚢 Web Release Workflow

`.github/workflows/web-release.yml` publishes static web builds to the external
release repository `emmett-ola/cashlenx-app-release`.

The workflow runs on pushes to `main`, pushes to `dev/**`, and manual dispatch.
It creates `.env` from repository variables, installs dependencies, regenerates
code, runs analysis and tests, builds Flutter web, and publishes `build/web`.

Branch routing:

- Source branch `main` publishes to release branch `main`.
- Source branches under `dev/**` publish to release branch `develop`.

Required GitHub configuration:

- Variables: `APP_ENV`, `API_SCHEME`, `API_DOMAIN`, `API_PORT`, `API_VERSION`.
- Secret: `RELEASE_REPO_TOKEN` with permission to push to the release repo.

## 🧪 Testing

Run analysis plus unit/widget tests:

```bash
flutter analyze
flutter test
```

Run the disposable Flutter-to-server contract on Windows with MongoDB (default)
or MySQL 8:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/smoke-api.ps1
powershell -ExecutionPolicy Bypass -File scripts/smoke-api.ps1 -Database mysql
```

The smoke flow covers registration and password reset without sending real
email. See [Testing Strategy](docs/testing.md) for details.

## 📚 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [Infrastructure Foundation](docs/infrastructure.md)
- [Development Roadmap](docs/roadmap.md)
- [Testing Strategy](docs/testing.md)

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
