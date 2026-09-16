#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"
compose_file="$project_dir/docker/compose.yml"

resolve_env_file() {
  local requested="${ENV_FILE:-.env}"
  local candidate
  if [[ "$requested" == /* ]]; then
    candidate="$requested"
  else
    candidate="$project_dir/$requested"
  fi

  if [[ ! -e "$candidate" ]]; then
    echo "Missing environment file: $requested" >&2
    echo "Create it with: cp .env.example \"$requested\"" >&2
    return 1
  fi
  [[ -f "$candidate" ]] || { echo "Environment path is not a file: $requested" >&2; return 1; }

  local resolved
  resolved="$(realpath "$candidate")"
  case "$resolved" in
    "$project_dir"/*) printf '%s\n' "$resolved" ;;
    *) echo "ENV_FILE must stay inside $project_dir: $requested" >&2; return 1 ;;
  esac
}

command -v docker >/dev/null 2>&1 || { echo "Docker is required." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose is required." >&2; exit 1; }

env_file="$(resolve_env_file)"

git_commit="${GIT_COMMIT:-$(git rev-parse HEAD)}"
[[ "$git_commit" =~ ^[0-9a-fA-F]{40}$ ]] || { echo "GIT_COMMIT must be a full 40-character Git revision." >&2; exit 1; }

product_version="${PRODUCT_VERSION:-$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml | tr -d '\r')}"
[[ "$product_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] || { echo "PRODUCT_VERSION must be a semantic version." >&2; exit 1; }

read_env_value() {
  local key="$1"
  local fallback="$2"
  local value
  value="$(sed -n "s/^${key}=//p" "$env_file" | tail -n 1 | tr -d '\r')"
  printf '%s\n' "${value:-$fallback}"
}

app_env="$(read_env_value APP_ENV dev)"
api_scheme="$(read_env_value API_SCHEME http)"
api_domain="$(read_env_value API_DOMAIN 127.0.0.1)"
api_port="$(read_env_value API_PORT 10063)"
api_version="$(read_env_value API_VERSION api/v1)"

[[ "$app_env" =~ ^(dev|staging|prod)$ ]] || { echo "APP_ENV must be dev, staging, or prod." >&2; exit 1; }
[[ "$api_scheme" =~ ^https?$ ]] || { echo "API_SCHEME must be http or https." >&2; exit 1; }
[[ "$api_domain" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "API_DOMAIN must be a hostname or IP address without a path." >&2; exit 1; }
if [[ -n "$api_port" ]]; then
  [[ "$api_port" =~ ^[0-9]+$ ]] && (( api_port >= 1 && api_port <= 65535 )) || { echo "API_PORT must be empty or an integer from 1 to 65535." >&2; exit 1; }
fi
[[ "$api_version" =~ ^[A-Za-z0-9._/-]+$ && "$api_version" != /* ]] || { echo "API_VERSION must be a relative URL path." >&2; exit 1; }

APP_ENV="$app_env" API_SCHEME="$api_scheme" API_DOMAIN="$api_domain" API_PORT="$api_port" API_VERSION="$api_version" \
PRODUCT_VERSION="$product_version" GIT_COMMIT="$git_commit" \
  docker compose --env-file "$project_dir/docker/images.env" --env-file "$env_file" -f "$compose_file" build cashlenx-web

image_ref="$(APP_ENV="$app_env" API_SCHEME="$api_scheme" API_DOMAIN="$api_domain" API_PORT="$api_port" API_VERSION="$api_version" \
  PRODUCT_VERSION="$product_version" GIT_COMMIT="$git_commit" \
  docker compose --env-file "$project_dir/docker/images.env" --env-file "$env_file" -f "$compose_file" config --images | awk 'NF { print; exit }')"
"$project_dir/scripts/verify-image.sh" "$image_ref" "$product_version" "$git_commit"
