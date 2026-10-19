#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"
. "$project_dir/scripts/lib/container_lifecycle.sh"
. "$project_dir/scripts/lib/flutter_config.sh"
ENV_FILE="${ENV_FILE:-.env.example}"
env_file="$(resolve_env_file)"
container_runtime_init "$(read_config_value CONTAINER_FRONTEND auto "$env_file")"

output_dir="${1:?output directory is required}"
if command -v cygpath >/dev/null 2>&1; then
  output_dir="$(cygpath -u "$output_dir")"
fi
expected_version="${PRODUCT_VERSION:-$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml | tr -d '\r' | sed 's/+.*//')}"
source_version="$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml | tr -d '\r')"
source_product_version="${source_version%%+*}"
revision="${GIT_COMMIT:-$(git rev-parse HEAD)}"
build_date="${BUILD_DATE:-$(date -u +%F)}"

[[ "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || { echo "PRODUCT_VERSION must be a semantic product version without build metadata." >&2; exit 1; }
[[ "$source_product_version" == "$expected_version" ]] || { echo "pubspec.yaml version does not match PRODUCT_VERSION." >&2; exit 1; }
[[ "$revision" =~ ^[0-9a-fA-F]{40}$ && "$(git rev-parse HEAD)" == "$revision" ]] || { echo "GIT_COMMIT must equal the checked-out full revision." >&2; exit 1; }
[[ "$build_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "BUILD_DATE must use UTC YYYY-MM-DD format." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Release packaging requires a clean worktree." >&2; exit 1; }

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd -P)"
short_revision="${revision:0:12}"
load_flutter_config
public_configuration_sha256="$(printf 'APP_ENV=%s\nAPI_SCHEME=%s\nAPI_DOMAIN=%s\nAPI_PORT=%s\nAPI_VERSION=%s\n' \
  "$app_env" "$api_scheme" "$api_domain" "$api_port" "$api_version" | sha256sum | awk '{print $1}')"
configuration_identity="${app_env}-${public_configuration_sha256:0:12}"
artifact="cashlenx-app-${expected_version}-${short_revision}-${configuration_identity}.image.tar"
image_name="cashlenx-app-candidate"
image_tag="${expected_version}-${short_revision}-${configuration_identity}"
image_ref="${image_name}:${image_tag}"

BUILDX_NO_DEFAULT_ATTESTATIONS=1 ENV_FILE="$ENV_FILE" IMAGE_NAME="$image_name" IMAGE_TAG="$image_tag" \
  APP_ENV="$app_env" API_SCHEME="$api_scheme" API_DOMAIN="$api_domain" API_PORT="$api_port" API_VERSION="$api_version" \
  PRODUCT_VERSION="$expected_version" GIT_COMMIT="$revision" BUILD_DATE="$build_date" "$project_dir/scripts/build.sh"

image_id="$(container image inspect "$image_ref" --format '{{.Id}}')"
save_image "$output_dir/$artifact" "$image_ref"
artifact_sha="$(sha256sum "$output_dir/$artifact" | awk '{print $1}')"
input_sha="$(sha256sum pubspec.lock docker/Dockerfile docker/images.env | sha256sum | awk '{print $1}')"

printf '{"schema_version":2,"component":"app","artifact":"%s","artifact_sha256":"%s","image_id":"%s","image_ref":"%s","input_set_sha256":"%s","revision":"%s","version":"%s","build_date":"%s","configuration_profile":"%s","public_configuration_sha256":"%s"}\n' \
  "$artifact" "$artifact_sha" "$image_id" "$image_ref" "$input_sha" "$revision" "$expected_version" "$build_date" "$app_env" "$public_configuration_sha256" \
  > "$output_dir/${artifact}.json"
printf '%s  %s\n' "$artifact_sha" "$artifact" > "$output_dir/${artifact}.sha256"
