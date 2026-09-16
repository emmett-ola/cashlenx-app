#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"
. "$project_dir/scripts/lib/container_lifecycle.sh"
env_file="$(resolve_env_file)"
container_runtime_init "$(read_config_value CONTAINER_FRONTEND auto)"
load_env_defaults "$project_dir/docker/images.env" FLUTTER_BUILD_IMAGE NGINX_IMAGE
compose_args=(--env-file "$env_file" -f "$project_dir/docker/compose.yml")
compose_preflight "${compose_args[@]}"
diagnose_container "$(read_config_value CONTAINER_NAME cashlenx-app)" \
  "$(resolve_image_ref IMAGE_NAME cashlenx-app IMAGE_TAG latest)" "$(resolve_network_name)" \
  sh -ec 'wget --quiet --spider --timeout=3 http://127.0.0.1:8080/'
