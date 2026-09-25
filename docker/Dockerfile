ARG FLUTTER_BUILD_IMAGE=ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8
ARG NGINX_IMAGE=nginx:alpine@sha256:1ed1b0e1d7652937d6cbdaf4018c7b6fc009a7dd6c3047351e2eddda745de43f

FROM ${FLUTTER_BUILD_IMAGE} AS build

ARG FLUTTER_REVISION
ARG FLUTTER_VERSION
ARG DART_VERSION
RUN git -C "$FLUTTER_ROOT" fetch --depth 1 origin "refs/tags/${FLUTTER_VERSION}:refs/tags/${FLUTTER_VERSION}" \
 && git -C "$FLUTTER_ROOT" checkout --detach "$FLUTTER_VERSION" \
 && test "$(git -C "$FLUTTER_ROOT" rev-parse HEAD)" = "$FLUTTER_REVISION" \
 && flutter precache --web \
 && flutter_version_json="$(flutter --version --machine)" \
 && printf '%s\n' "$flutter_version_json" | grep -Eq '"frameworkVersion"[[:space:]]*:[[:space:]]*"'"${FLUTTER_VERSION}"'"' \
 && printf '%s\n' "$flutter_version_json" | grep -Eq '"dartSdkVersion"[[:space:]]*:[[:space:]]*"'"${DART_VERSION}"'"'

ARG APP_ENV=dev
ARG API_SCHEME=http
ARG API_DOMAIN=127.0.0.1
ARG API_PORT=10063
ARG API_VERSION=api/v1

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile

COPY . .
RUN flutter build web --release \
      --dart-define=APP_ENV="${APP_ENV}" \
      --dart-define=API_SCHEME="${API_SCHEME}" \
      --dart-define=API_DOMAIN="${API_DOMAIN}" \
      --dart-define=API_PORT="${API_PORT}" \
      --dart-define=API_VERSION="${API_VERSION}"

FROM ${NGINX_IMAGE}

ARG GIT_COMMIT=unknown
ARG PRODUCT_VERSION=0.0.0
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"
LABEL org.opencontainers.image.version="${PRODUCT_VERSION}"

WORKDIR /app

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
RUN printf '{"version":"%s","revision":"%s"}\n' "$PRODUCT_VERSION" "$GIT_COMMIT" > /usr/share/nginx/html/build-metadata.json

EXPOSE 8080
