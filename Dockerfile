FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

FROM nginx:alpine

WORKDIR /app

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/.env /app/.env
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
