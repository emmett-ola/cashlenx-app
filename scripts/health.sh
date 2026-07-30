#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

command -v curl >/dev/null 2>&1 || { echo "curl is required." >&2; exit 1; }
web_port="$(sed -n 's/^WEB_PORT=//p' .env 2>/dev/null | tail -n 1)"
web_port="${web_port:-11064}"
health_url="${APP_HEALTH_URL:-http://127.0.0.1:${web_port}/}"

for attempt in $(seq 1 30); do
  if curl --fail --silent --show-error "$health_url" >/dev/null; then
    echo "App web is healthy: $health_url"
    exit 0
  fi
  sleep 2
done

echo "App web health check failed: $health_url" >&2
docker compose ps cashlenx-web >&2
exit 1
