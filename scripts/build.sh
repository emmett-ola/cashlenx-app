#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"
compose_file="$project_dir/docker/compose.yml"
. "$project_dir/scripts/lib/container_lifecycle.sh"

env_file="$(resolve_env_file)"
container_runtime_init "$(read_config_value CONTAINER_FRONTEND auto)"
load_env_defaults "$project_dir/docker/images.env" FLUTTER_BUILD_IMAGE NGINX_IMAGE

git_commit="${GIT_COMMIT:-$(git rev-parse HEAD)}"
[[ "$git_commit" =~ ^[0-9a-fA-F]{40}$ ]] || { echo "GIT_COMMIT must be a full 40-character Git revision." >&2; exit 1; }
product_version="${PRODUCT_VERSION:-$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml | tr -d '\r')}"
[[ "$product_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] || { echo "PRODUCT_VERSION must be a semantic version." >&2; exit 1; }

app_env="$(read_config_value APP_ENV dev)"
api_scheme="$(read_config_value API_SCHEME http)"
api_domain="$(read_config_value API_DOMAIN 127.0.0.1)"
api_port="$(read_config_value API_PORT 10063)"
api_version="$(read_config_value API_VERSION api/v1)"
image_ref="$(resolve_image_ref IMAGE_NAME cashlenx-web IMAGE_TAG latest)"
[[ "$app_env" =~ ^(dev|staging|prod)$ ]] || { echo "APP_ENV must be dev, staging, or prod." >&2; exit 1; }
[[ "$api_scheme" =~ ^https?$ ]] || { echo "API_SCHEME must be http or https." >&2; exit 1; }
[[ "$api_domain" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "API_DOMAIN must be a hostname or IP address without a path." >&2; exit 1; }
if [[ -n "$api_port" ]]; then
  if [[ ! "$api_port" =~ ^[0-9]+$ ]] || ((api_port < 1 || api_port > 65535)); then
    echo "API_PORT must be empty or an integer from 1 to 65535." >&2
    exit 1
  fi
fi
[[ "$api_version" =~ ^[A-Za-z0-9._/-]+$ && "$api_version" != /* ]] || { echo "API_VERSION must be a relative URL path." >&2; exit 1; }

export APP_ENV="$app_env" API_SCHEME="$api_scheme" API_DOMAIN="$api_domain" API_PORT="$api_port" API_VERSION="$api_version"
export PRODUCT_VERSION="$product_version" GIT_COMMIT="$git_commit"
compose_args=(--env-file "$env_file" -f "$compose_file")
compose_preflight "${compose_args[@]}"
compose "${compose_args[@]}" build cashlenx-web
"$project_dir/scripts/verify-image.sh" "$image_ref" "$product_version" "$git_commit"
