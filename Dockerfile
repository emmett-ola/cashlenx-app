ARG FLUTTER_BUILD_IMAGE=ghcr.io/cirruslabs/flutter:stable
ARG NGINX_IMAGE=nginx:alpine

FROM ${FLUTTER_BUILD_IMAGE} AS build

ARG APP_ENV_FILE=.env

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
COPY ${APP_ENV_FILE} .env
RUN flutter build web --release

FROM ${NGINX_IMAGE}

ARG GIT_COMMIT=unknown
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"

WORKDIR /app

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/.env /app/.env
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
