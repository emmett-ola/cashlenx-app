#!/usr/bin/env bash

# The caller resolves env_file with the repository-local environment loader.
# Never source the file or forward its complete contents to Flutter.
read_flutter_setting() {
  local key="$1"
  local fallback="$2"
  if [[ -n "${!key+x}" ]]; then
    printf '%s\n' "${!key}"
  elif awk -v key="$key" '
    $0 ~ "^[[:space:]]*(export[[:space:]]+)?" key "[[:space:]]*=" { found = 1 }
    END { exit !found }
  ' "$env_file"; then
    read_env_value "$key"
  else
    printf '%s\n' "$fallback"
  fi
}

load_flutter_config() {
  app_env="$(read_flutter_setting APP_ENV dev)"
  api_scheme="$(read_flutter_setting API_SCHEME http)"
  api_domain="$(read_flutter_setting API_DOMAIN 127.0.0.1)"
  api_port="$(read_flutter_setting API_PORT 10063)"
  api_version="$(read_flutter_setting API_VERSION api/v1)"

  [[ "$app_env" =~ ^(dev|staging|prod)$ ]] || { echo 'APP_ENV must be dev, staging, or prod.' >&2; return 1; }
  [[ "$api_scheme" =~ ^https?$ ]] || { echo 'API_SCHEME must be http or https.' >&2; return 1; }
  [[ "$api_domain" =~ ^[A-Za-z0-9.-]+$ ]] || { echo 'API_DOMAIN must be a hostname or IP address without a path.' >&2; return 1; }
  if [[ -n "$api_port" ]]; then
    if [[ ! "$api_port" =~ ^[0-9]{1,5}$ ]] || ((10#$api_port < 1 || 10#$api_port > 65535)); then
      echo 'API_PORT must be empty or an integer from 1 to 65535.' >&2
      return 1
    fi
  fi
  [[ "$api_version" =~ ^[A-Za-z0-9._/-]+$ && "$api_version" != /* ]] || { echo 'API_VERSION must be a relative URL path.' >&2; return 1; }

  flutter_defines=(
    "--dart-define=APP_ENV=$app_env"
    "--dart-define=API_SCHEME=$api_scheme"
    "--dart-define=API_DOMAIN=$api_domain"
    "--dart-define=API_PORT=$api_port"
    "--dart-define=API_VERSION=$api_version"
  )
}
