# CashLenX App

CashLenX is a modern, cross-platform finance application built with Flutter. It aims to provide a seamless experience for managing personal finances, tracking expenses, and planning budgets.

## CashLenX Project

CashLenX is developed as a set of independently buildable repositories with
explicit ownership boundaries:

| Repository | Responsibility |
| --- | --- |
| [cashlenx-app](https://github.com/emmett-ola/cashlenx-app) | Cross-platform Flutter client and user experience. |
| [cashlenx-server](https://github.com/emmett-ola/cashlenx-server) | Go REST API, Cobra CLI, authentication, finance services, and MongoDB/MySQL persistence. |
| [cashlenx-design](https://github.com/emmett-ola/cashlenx-design) | Figma-exported React/Vite visual and interaction reference. |
| [cashlenx-website](https://github.com/emmett-ola/cashlenx-website) | Public product and developer-information website. |
| [cashlenx-spec](https://github.com/emmett-ola/cashlenx-spec) | Product and system facts, delivery workflow, decisions, and retained evidence. |

This repository owns the user-facing application. Cross-repository contracts
are coordinated through OpenAPI and the CashLenX Spec workflow. Runtime
repositories remain independently buildable and do not depend on the spec or
design reference at build time or runtime.

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
    cp .env.example .env
    ```

    Every assignment in `.env.example` is active. Change values directly; no
    configuration is enabled by uncommenting a line.

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
scripts/stop.sh
```

`build.sh` compiles the Flutter web app and builds its image. `start.sh` starts
or updates the container from that existing image without rebuilding and waits
on an in-container HTTP readiness probe. It does not require Compose `up --wait`
or Compose-managed health status. `stop.sh` removes the project container while
preserving built images and persistent volumes. It removes the shared network
only when no CashLenX container remains attached.

The lifecycle supports Docker Compose v2 and nerdctl 2.2 or newer. Set
`CONTAINER_FRONTEND=auto` (the default), `docker`, or `nerdctl`; auto mode
inspects the command's reported implementation, so a command named `docker`
that wraps nerdctl is handled as nerdctl. Set `CONTAINER_CLI` in the invoking
shell only when the executable has a nonstandard name or path. Every entry point
validates the runtime and Compose configuration before mutation. Image identity
comes directly from the validated `IMAGE_NAME` and `IMAGE_TAG` values; scripts
must not depend on frontend-specific `compose config --images` output. Start
commands suppress frontend command traces so environment values cannot leak
through nerdctl's informational output.

All three scripts use `.env` by default. Select another repository-local file
consistently across the lifecycle with, for example,
`ENV_FILE=.env.testing scripts/build.sh`. The same prefix applies to `start.sh`
and `stop.sh`. Missing files and paths outside this repository are rejected;
`.env` may also be a symbolic link to a repository-local `.env.local`,
`.env.testing`, or `.env.production`. Links resolving outside the repository are
rejected. `start.sh` also rejects active `CHANGE_ME` or known legacy weak values.

Compose reads `docker/compose.yml` and builds from `docker/Dockerfile`. The
container serves the built web app on internal port `8080`, and by default
Compose exposes it on host port `10064`:

```text
http://SERVER_IP:10064
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

The default project, container, and shared-network names are `cashlenx-app`,
`cashlenx-app`, and `cashlenx-network`. Configure them explicitly with
`APP_PROJECT_NAME`, `CONTAINER_NAME`, and `DOCKER_NETWORK_NAME`. `start.sh`
creates the external network when needed; keep its absolute name identical in
every CashLenX environment file.

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
127.0.0.1:10064
```

The build script reads only public compile-time settings from the selected
repository-local environment file. Environment files are excluded from the
Docker context and runtime image.

Run `test/scripts/container-lifecycle-smoke.sh` to exercise Docker and nerdctl
2.2 command shapes, wrapper detection, symlink selection, and pre-mutation
failure paths without changing containers.

## 🚢 Web Candidate Workflow

`.github/workflows/ci.yml` installs locked dependencies, regenerates code, runs
analysis and tests, and builds Flutter Web against canonical `/api/v1`.

Manual dispatch adds a verified, untagged container-image artifact with exact
version, revision, image identity, build-input digest, and SHA-256 sidecars. It
does not need a secret and does not publish externally, promote a branch, or
deploy. Release publication consumes an already accepted candidate under the
coordinated release gate rather than rebuilding it.

The candidate tag and metadata also include the App configuration profile and
the normalized SHA-256 fingerprint of `APP_ENV`, `API_SCHEME`, `API_DOMAIN`,
`API_PORT`, and `API_VERSION`. This makes two builds from the same source but
different public API configuration distinct artifacts. `start.sh` uses
`--pull never`, so an absent exact image fails instead of resolving a mutable
registry tag.

The repository-local packaging entry point is:

```bash
scripts/package-image.sh /absolute/output/directory
```

## 🧪 Testing

Run analysis plus unit/widget tests:

```bash
flutter analyze
flutter test
```

The repository currently has no maintained live Flutter-to-server harness.
Use package tests for app changes and the server repository's focused API smoke
checks for backend integration. See [Testing Strategy](docs/testing.md) for the
current boundary.

## 📚 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [Infrastructure Foundation](docs/infrastructure.md)
- [Development Roadmap](docs/roadmap.md)
- [Testing Strategy](docs/testing.md)
- [Contributing](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Shared Governance](https://github.com/emmett-ola/cashlenx-spec/blob/main/GOVERNANCE.md)
- [Shared Delivery Workflow](https://github.com/emmett-ola/cashlenx-spec/blob/main/WORKFLOW.md)

## 📄 License

This project is licensed under the [MIT License](LICENSE). Commercial use,
modification, and redistribution are permitted when the copyright and license
notices are retained.
