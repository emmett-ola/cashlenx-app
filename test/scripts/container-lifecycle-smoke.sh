#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fake_dir="$(mktemp -d)"
fake_log="$fake_dir/container.log"
linked_env="$project_dir/.env.lifecycle-link"

cleanup() {
  rm -f "$linked_env"
  rm -rf "$fake_dir"
}
trap cleanup EXIT

cat > "$fake_dir/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_CONTAINER_LOG"
case "${1:-}" in
  --version)
    case "${FAKE_FRONTEND_KIND:-docker}" in
      docker) echo 'Docker version 29.0.0, build fake' ;;
      old-nerdctl) echo 'nerdctl version 2.1.0' ;;
      *) echo 'nerdctl version 2.2.0' ;;
    esac
    exit 0
    ;;
  info) exit 0 ;;
esac
if [[ "${1:-}" == compose && "${2:-}" == version ]]; then
  case "${FAKE_FRONTEND_KIND:-docker}" in
    docker) echo 'Docker Compose version v2.29.0' ;;
    old-nerdctl) echo 'nerdctl compose version 2.1.0' ;;
    *) echo 'nerdctl compose version 2.2.0' ;;
  esac
  if [[ "${FAKE_VERBOSE_VERSION:-false}" == true ]]; then
    for ((line = 0; line < 4096; line++)); do echo 'nerdctl compose version 2.2.0'; done
  fi
  exit 0
fi
if [[ "${1:-}" == compose && "$*" == *' config --quiet'* ]]; then
  [[ "${FAKE_CONFIG_SUPPORTED:-true}" == true ]]
  exit
fi
if [[ "${1:-}" == compose && "$*" == *' up '* && -n "${FAKE_SECRET_OUTPUT:-}" ]]; then echo "$FAKE_SECRET_OUTPUT" >&2; fi
if [[ "${1:-}" == network && "${2:-}" == inspect ]]; then exit 1; fi
if [[ "${1:-}" == inspect ]]; then echo running; exit 0; fi
if [[ "${1:-}" == exec ]]; then exit 0; fi
if [[ "${1:-}" == image && "${2:-}" == inspect ]]; then
  if [[ "$*" == *org.opencontainers.image.version* ]]; then echo "$FAKE_IMAGE_VERSION"
  elif [[ "$*" == *org.opencontainers.image.revision* ]]; then echo "$FAKE_IMAGE_REVISION"
  else echo 'sha256:fake'; fi
  exit 0
fi
if [[ "${1:-}" == run && "$*" == *'--entrypoint cat'* ]]; then
  printf '{"version":"%s","revision":"%s"}\n' "$FAKE_IMAGE_VERSION" "$FAKE_IMAGE_REVISION"
fi
EOF
chmod +x "$fake_dir/docker"

image_version="$(awk '$1 == "version:" { print $2; exit }' "$project_dir/pubspec.yaml")"
image_revision="$(git -C "$project_dir" rev-parse HEAD)"

reset_log() { : > "$fake_log"; }
run_script() {
  PATH="$fake_dir:$PATH" FAKE_CONTAINER_LOG="$fake_log" \
    FAKE_FRONTEND_KIND="${FAKE_FRONTEND_KIND:-docker}" \
    FAKE_VERBOSE_VERSION="${FAKE_VERBOSE_VERSION:-false}" \
    FAKE_SECRET_OUTPUT="${FAKE_SECRET_OUTPUT:-}" \
    FAKE_CONFIG_SUPPORTED="${FAKE_CONFIG_SUPPORTED:-true}" \
    FAKE_IMAGE_VERSION="$image_version" FAKE_IMAGE_REVISION="$image_revision" \
    ENV_FILE="${2:-.env.example}" bash "$project_dir/$1"
}
assert_log_contains() { grep -F -- "$1" "$fake_log" >/dev/null || { echo "Expected call containing: $1" >&2; exit 1; }; }
assert_log_not_contains() { if grep -F -- "$1" "$fake_log" >/dev/null; then echo "Unexpected call containing: $1" >&2; exit 1; fi; }

for frontend in docker nerdctl; do
  reset_log
  FAKE_FRONTEND_KIND="$frontend" run_script scripts/build.sh
  FAKE_FRONTEND_KIND="$frontend" run_script scripts/start.sh
  FAKE_FRONTEND_KIND="$frontend" run_script scripts/stop.sh
  assert_log_contains "image inspect cashlenx-app:latest"
  assert_log_contains "up -d --no-build --pull never --remove-orphans cashlenx-web"
  assert_log_contains "down --remove-orphans"
  assert_log_not_contains "config --images"
  assert_log_not_contains "--wait"
  assert_log_not_contains "docker/images.env --env-file"
done

reset_log
FAKE_FRONTEND_KIND=nerdctl FAKE_VERBOSE_VERSION=true run_script scripts/start.sh
assert_log_contains "up -d --no-build --pull never --remove-orphans cashlenx-web"

reset_log
output="$(FAKE_SECRET_OUTPUT=lifecycle-sensitive-value run_script scripts/start.sh 2>&1)"
if grep -F 'lifecycle-sensitive-value' <<< "$output" >/dev/null; then echo "Start output exposed a configured value" >&2; exit 1; fi

reset_log
if output="$(FAKE_FRONTEND_KIND=old-nerdctl run_script scripts/start.sh 2>&1)"; then
  echo "Expected nerdctl 2.1 to be rejected" >&2
  exit 1
fi
grep -F 'Install nerdctl 2.2 or newer' <<< "$output" >/dev/null
assert_log_not_contains "network create"
assert_log_not_contains " up "

reset_log
if output="$(FAKE_CONFIG_SUPPORTED=false run_script scripts/start.sh 2>&1)"; then
  echo "Expected unsupported Compose configuration to be rejected" >&2
  exit 1
fi
grep -F 'cannot validate this Compose configuration' <<< "$output" >/dev/null
assert_log_not_contains "network create"
assert_log_not_contains " up "

ln -s .env.example "$linked_env" 2>/dev/null || true
if [[ -L "$linked_env" ]]; then
  reset_log
  run_script scripts/start.sh "${linked_env#"$project_dir"/}"
  assert_log_contains "--env-file $(realpath "$linked_env")"
fi

echo "App container lifecycle smoke checks passed."
