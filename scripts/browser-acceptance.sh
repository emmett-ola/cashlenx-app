#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
compose_file="$project_dir/test/browser/compose.yml"
evidence_dir="${BROWSER_EVIDENCE_DIR:-$project_dir/test/browser/artifacts}"

: "${ADMIN_USERNAME:?ADMIN_USERNAME is required}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD is required}"

mkdir -p "$evidence_dir"
export BROWSER_EVIDENCE_DIR="$evidence_dir"
export DOCKER_NETWORK_NAME="${DOCKER_NETWORK_NAME:-cashlenx-network}"

docker compose -f "$compose_file" build browser-acceptance
docker compose -f "$compose_file" run --rm browser-acceptance
