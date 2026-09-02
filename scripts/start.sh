#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"
compose_file="$project_dir/docker/compose.yml"
. "$project_dir/scripts/lib/container_readiness.sh"

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

read_env_value() {
  local key="$1"
  awk -F= -v wanted="$key" '
    $0 ~ "^[[:space:]]*(export[[:space:]]+)?" wanted "[[:space:]]*=" {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if ((substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") ||
          (substr(value, 1, 1) == "\047" && substr(value, length(value), 1) == "\047")) {
        value = substr(value, 2, length(value) - 2)
      }
      result = value
    }
    END { print result }
  ' "$env_file"
}

resolve_network_name() {
  local name
  name="$(read_env_value DOCKER_NETWORK_NAME)"
  name="${name:-cashlenx-network}"
  if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    echo "Invalid Docker network setting: DOCKER_NETWORK_NAME" >&2
    return 1
  fi
  printf '%s\n' "$name"
}

ensure_network() {
  local name="$1"
  if docker network inspect "$name" >/dev/null 2>&1; then
    return 0
  fi
  docker network create --driver bridge "$name" >/dev/null 2>&1 ||
    docker network inspect "$name" >/dev/null 2>&1
}

validate_no_unsafe_values() {
  local invalid_keys
  invalid_keys="$(awk -F= '
    function clean(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if ((substr(value, 1, 1) == "\"" && substr(value, length(value), 1) == "\"") ||
          (substr(value, 1, 1) == "\047" && substr(value, length(value), 1) == "\047")) {
        value = substr(value, 2, length(value) - 2)
      }
      return value
    }
    /^[A-Za-z_][A-Za-z0-9_]*=/ {
      key = $1
      value = clean(substr($0, index($0, "=") + 1))
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
    while IFS= read -r key; do
      [[ -n "$key" ]] && echo "  - $key" >&2
    done <<< "$invalid_keys"
    return 1
  fi
}

command -v docker >/dev/null 2>&1 || { echo "Docker is required." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose is required." >&2; exit 1; }

env_file="$(resolve_env_file)"
env_relative="${env_file#"$project_dir"/}"
validate_no_unsafe_values
network_name="$(resolve_network_name)"

container_name="$(sed -n 's/^CONTAINER_NAME=//p' "$env_file" | tail -n 1)"
if [[ "$container_name" == "cashlenx-website" ]]; then
  echo "Legacy CONTAINER_NAME=cashlenx-website conflicts with the product website." >&2
  echo "Set CONTAINER_NAME=cashlenx-app in $env_relative before starting." >&2
  exit 1
fi

ensure_network "$network_name"
container_name="$(read_env_value CONTAINER_NAME)"
container_name="${container_name:-cashlenx-app}"
RUNTIME_ENV_FILE="../$env_relative" \
  docker compose --env-file "$env_file" -f "$compose_file" up -d --no-build --remove-orphans cashlenx-web
wait_for_container_command "$container_name" sh -ec \
  'wget --quiet --spider --timeout=3 http://127.0.0.1:8080/'
