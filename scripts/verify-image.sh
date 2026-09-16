#!/usr/bin/env bash
set -euo pipefail

# Prevent Git Bash on Windows from rewriting container-internal absolute paths.
export MSYS_NO_PATHCONV=1

image_ref="${1:?image reference is required}"
expected_version="${2:?expected version is required}"
expected_revision="${3:?expected revision is required}"

label() {
  docker image inspect "$image_ref" --format "{{ index .Config.Labels \"$1\" }}"
}

[[ "$(label org.opencontainers.image.version)" == "$expected_version" ]] || { echo "Image version label mismatch." >&2; exit 1; }
[[ "$(label org.opencontainers.image.revision)" == "$expected_revision" ]] || { echo "Image revision label mismatch." >&2; exit 1; }

docker run --rm --entrypoint sh "$image_ref" -ec '
  test -s /usr/share/nginx/html/index.html
  test -s /usr/share/nginx/html/build-metadata.json
  test -s /etc/nginx/conf.d/default.conf
  if find /usr/share/nginx/html /etc/nginx/conf.d -type f \( -name ".env" -o -name ".env.*" -o -name "*.pem" -o -name "*.key" \) -print -quit 2>/dev/null | grep -q .; then
    echo "Prohibited environment or credential file found in image." >&2
    exit 1
  fi
  if find /usr/share/nginx/html /etc/nginx/conf.d -type d -name .git -print -quit 2>/dev/null | grep -q .; then
    echo "Git metadata found in image." >&2
    exit 1
  fi
'

metadata="$(docker run --rm --entrypoint cat "$image_ref" /usr/share/nginx/html/build-metadata.json)"
grep -Fq "\"version\":\"${expected_version}\"" <<<"$metadata" || { echo "Public build version metadata mismatch." >&2; exit 1; }
grep -Fq "\"revision\":\"${expected_revision}\"" <<<"$metadata" || { echo "Public build revision metadata mismatch." >&2; exit 1; }
