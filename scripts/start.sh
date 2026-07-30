#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

command -v docker >/dev/null 2>&1 || { echo "Docker is required." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose is required." >&2; exit 1; }
[[ -f .env ]] || { echo "Missing .env. Create it from .env.sample and set the UAT values." >&2; exit 1; }

container_name="$(sed -n 's/^CONTAINER_NAME=//p' .env | tail -n 1)"
if [[ "$container_name" == "cashlenx-website" ]]; then
  echo "Legacy CONTAINER_NAME=cashlenx-website conflicts with the product website." >&2
  echo "Set CONTAINER_NAME=cashlenx-app in .env before starting." >&2
  exit 1
fi

docker compose up -d --no-build --remove-orphans cashlenx-web
"$project_dir/scripts/health.sh"
