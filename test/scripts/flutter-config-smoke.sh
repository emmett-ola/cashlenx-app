#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fixture_dir="$(mktemp -d "$project_dir/.env.flutter-test.XXXXXX")"
trap 'rm -rf "$fixture_dir"' EXIT
mkdir "$fixture_dir/bin"
export FAKE_FLUTTER_ARGS="$fixture_dir/args"
cat > "$fixture_dir/bin/flutter" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_FLUTTER_ARGS"
exit "${FAKE_FLUTTER_EXIT:-0}"
EOF
chmod +x "$fixture_dir/bin/flutter"
export PATH="$fixture_dir/bin:$PATH"
unset APP_ENV API_SCHEME API_DOMAIN API_PORT API_VERSION

cat > "$fixture_dir/config" <<EOF
APP_ENV=dev
API_SCHEME=http
API_DOMAIN='192.0.2.23'
API_PORT=10063
API_VERSION=api/v1
UNRELATED_SECRET=never-compile-this
UNUSED_EXPRESSION=\$(touch "$fixture_dir/executed")
EOF

run_app() { ENV_FILE="$fixture_dir/config" "$project_dir/scripts/run.sh" "$@"; }
assert_arg() { grep -Fx -- "$1" "$FAKE_FLUTTER_ARGS" >/dev/null; }
expect_failure() {
  rm -f "$FAKE_FLUTTER_ARGS"
  if "$@" > "$fixture_dir/error" 2>&1; then
    echo 'Expected invalid configuration to fail.' >&2
    exit 1
  fi
  [[ ! -e "$FAKE_FLUTTER_ARGS" ]] || { echo 'Flutter ran before configuration validation.' >&2; exit 1; }
}

run_app --device-id fake-device
assert_arg run
assert_arg --dart-define=APP_ENV=dev
assert_arg --dart-define=API_SCHEME=http
assert_arg --dart-define=API_DOMAIN=192.0.2.23
assert_arg --dart-define=API_PORT=10063
assert_arg --dart-define=API_VERSION=api/v1
assert_arg fake-device
[[ "$(wc -l < "$FAKE_FLUTTER_ARGS" | tr -d ' ')" == 8 ]]
[[ ! -e "$fixture_dir/executed" ]]
! grep -F 'never-compile-this' "$FAKE_FLUTTER_ARGS"

API_DOMAIN=192.0.2.44 API_PORT= run_app
assert_arg --dart-define=API_DOMAIN=192.0.2.44
assert_arg --dart-define=API_PORT=

sed 's/API_PORT=10063/API_PORT=/' "$fixture_dir/config" > "$fixture_dir/https"
ENV_FILE="$fixture_dir/https" API_SCHEME=https "$project_dir/scripts/run.sh"
assert_arg --dart-define=API_PORT=
assert_arg --dart-define=API_SCHEME=https

printf 'API_DOMAIN=localhost\n' > "$fixture_dir/defaults"
ENV_FILE="$fixture_dir/defaults" "$project_dir/scripts/run.sh"
assert_arg --dart-define=API_DOMAIN=localhost
assert_arg --dart-define=API_PORT=10063

for assignment in APP_ENV=unknown API_SCHEME=ftp API_DOMAIN=invalid/path API_PORT=65536 API_PORT=999999999999999999999 API_VERSION=/api/v1; do
  expect_failure env "$assignment" ENV_FILE="$fixture_dir/config" "$project_dir/scripts/run.sh"
done
expect_failure env ENV_FILE="$fixture_dir/missing" "$project_dir/scripts/run.sh"
expect_failure env ENV_FILE=/etc/hosts "$project_dir/scripts/run.sh"
ln -s /etc/hosts "$fixture_dir/outside"
expect_failure env ENV_FILE="$fixture_dir/outside" "$project_dir/scripts/run.sh"
expect_failure run_app --dart-define=API_DOMAIN=unexpected.invalid
expect_failure run_app --dart-define-from-file .env

set +e
FAKE_FLUTTER_EXIT=41 run_app
status=$?
set -e
[[ "$status" == 41 ]]

echo 'Flutter configuration smoke checks passed.'
