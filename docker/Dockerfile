ARG FLUTTER_BUILD_IMAGE=ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8
ARG NGINX_IMAGE=nginx:alpine@sha256:db35bfc6b2951e7f8a72db5db120288c127ffaeeb4a6d4b95a26fead017d5913

FROM ${FLUTTER_BUILD_IMAGE} AS build

ARG FLUTTER_VERSION
ARG DART_VERSION
RUN flutter --version --machine | grep -F '"frameworkVersion": "'"${FLUTTER_VERSION}"'"' >/dev/null \
 && dart --version 2>&1 | grep -F "Dart SDK version: ${DART_VERSION}" >/dev/null

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
