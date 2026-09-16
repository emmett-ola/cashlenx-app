#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"

output_dir="${1:?output directory is required}"
if command -v cygpath >/dev/null 2>&1; then
  output_dir="$(cygpath -u "$output_dir")"
fi
expected_version="${PRODUCT_VERSION:-$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml | tr -d '\r' | sed 's/+.*//')}"
source_version="$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml | tr -d '\r')"
source_product_version="${source_version%%+*}"
revision="${GIT_COMMIT:-$(git rev-parse HEAD)}"

[[ "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || { echo "PRODUCT_VERSION must be a semantic product version without build metadata." >&2; exit 1; }
[[ "$source_product_version" == "$expected_version" ]] || { echo "pubspec.yaml version does not match PRODUCT_VERSION." >&2; exit 1; }
[[ "$revision" =~ ^[0-9a-fA-F]{40}$ && "$(git rev-parse HEAD)" == "$revision" ]] || { echo "GIT_COMMIT must equal the checked-out full revision." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Release packaging requires a clean worktree." >&2; exit 1; }

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd -P)"
short_revision="${revision:0:12}"
artifact="cashlenx-app-${expected_version}-${short_revision}.image.tar"
image_name="cashlenx-app-candidate"
image_tag="${expected_version}-${short_revision}"
image_ref="${image_name}:${image_tag}"

BUILDX_NO_DEFAULT_ATTESTATIONS=1 ENV_FILE="${ENV_FILE:-.env.example}" IMAGE_NAME="$image_name" IMAGE_TAG="$image_tag" \
  PRODUCT_VERSION="$expected_version" GIT_COMMIT="$revision" "$project_dir/scripts/build.sh"

image_id="$(docker image inspect "$image_ref" --format '{{.Id}}')"
docker image save --output "$output_dir/$artifact" "$image_ref"
artifact_sha="$(sha256sum "$output_dir/$artifact" | awk '{print $1}')"
input_sha="$(sha256sum pubspec.lock docker/Dockerfile docker/images.env | sha256sum | awk '{print $1}')"

printf '{"artifact":"%s","artifact_sha256":"%s","image_id":"%s","input_set_sha256":"%s","revision":"%s","version":"%s"}\n' \
  "$artifact" "$artifact_sha" "$image_id" "$input_sha" "$revision" "$expected_version" \
  > "$output_dir/${artifact}.json"
printf '%s  %s\n' "$artifact_sha" "$artifact" > "$output_dir/${artifact}.sha256"
