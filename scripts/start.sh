#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"
compose_file="$project_dir/docker/compose.yml"
. "$project_dir/scripts/lib/container_lifecycle.sh"

validate_no_unsafe_values() {
  local invalid_keys
  invalid_keys="$(awk -F= '
    function clean(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if ((substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") || (substr(value, 1, 1) == "\047" && substr(value, length(value), 1) == "\047")) value = substr(value, 2, length(value) - 2)
      return value
    }
    /^[A-Za-z_][A-Za-z0-9_]*=/ {
      key = $1; value = clean(substr($0, index($0, "=") + 1))
      invalid = index(value, "CHANGE_ME") > 0
      invalid = invalid || (key == "JWT_SECRET" && value == "your-secret-key-here-change-in-production")
      invalid = invalid || (key == "ADMIN_PASSWORD" && value == "admin")
      invalid = invalid || ((key == "MONGO_ROOT_PASSWORD" || key == "MYSQL_ROOT_PASSWORD" || key == "MYSQL_PASSWORD") && value == "cashlenx123")
      invalid = invalid || ((key == "MONGO_DB_URI" || key == "MYSQL_DB_URI") && index(value, "cashlenx123") > 0)
      if (invalid) print key
    }
  ' "$env_file" | sort -u)"
  if [[ -n "$invalid_keys" ]]; then
    echo "Unsafe or placeholder environment values must be replaced before start:" >&2
    while IFS= read -r key; do [[ -n "$key" ]] && echo "  - $key" >&2; done <<< "$invalid_keys"
    return 1
  fi
}

env_file="$(resolve_env_file)"
validate_no_unsafe_values
container_runtime_init "$(read_config_value CONTAINER_FRONTEND auto)"
load_env_defaults "$project_dir/docker/images.env" FLUTTER_BUILD_IMAGE NGINX_IMAGE
network_name="$(resolve_network_name)"
container_name="$(read_config_value CONTAINER_NAME cashlenx-app)"
if [[ "$container_name" == "cashlenx-website" ]]; then
  echo "Legacy CONTAINER_NAME=cashlenx-website conflicts with the product website." >&2
  echo "Set CONTAINER_NAME=cashlenx-app in ${env_file#"$project_dir"/} before starting." >&2
  exit 1
fi
compose_args=(--env-file "$env_file" -f "$compose_file")
compose_preflight "${compose_args[@]}"
ensure_network "$network_name"
compose_up_quiet "${compose_args[@]}" up -d --no-build --remove-orphans cashlenx-web
wait_for_container_command "$container_name" sh -ec 'wget --quiet --spider --timeout=3 http://127.0.0.1:8080/'
