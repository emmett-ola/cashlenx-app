#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"
compose_file="$project_dir/docker/compose.yml"
. "$project_dir/scripts/lib/container_lifecycle.sh"
. "$project_dir/scripts/lib/flutter_config.sh"

env_file="$(resolve_env_file)"
container_runtime_init "$(read_config_value CONTAINER_FRONTEND auto)"
load_env_defaults "$project_dir/docker/images.env" FLUTTER_BUILD_IMAGE FLUTTER_REVISION FLUTTER_VERSION DART_VERSION NGINX_IMAGE

git_commit="${GIT_COMMIT:-$(git rev-parse HEAD)}"
[[ "$git_commit" =~ ^[0-9a-fA-F]{40}$ ]] || { echo "GIT_COMMIT must be a full 40-character Git revision." >&2; exit 1; }
product_version="${PRODUCT_VERSION:-$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml | tr -d '\r')}"
[[ "$product_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] || { echo "PRODUCT_VERSION must be a semantic version." >&2; exit 1; }
build_date="${BUILD_DATE:-$(date -u +%F)}"
[[ "$build_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "BUILD_DATE must use UTC YYYY-MM-DD format." >&2; exit 1; }

load_flutter_config
image_ref="$(resolve_image_ref IMAGE_NAME cashlenx-web IMAGE_TAG latest)"

export APP_ENV="$app_env" API_SCHEME="$api_scheme" API_DOMAIN="$api_domain" API_PORT="$api_port" API_VERSION="$api_version"
export PRODUCT_VERSION="$product_version" GIT_COMMIT="$git_commit" BUILD_DATE="$build_date"
compose_args=(--env-file "$env_file" -f "$compose_file")
compose_preflight "${compose_args[@]}"
compose "${compose_args[@]}" build cashlenx-web
"$project_dir/scripts/verify-image.sh" "$image_ref" "$product_version" "$git_commit" "$build_date"
