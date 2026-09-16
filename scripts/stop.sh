#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"
compose_file="$project_dir/docker/compose.yml"
. "$project_dir/scripts/lib/container_lifecycle.sh"

env_file="$(resolve_env_file)"
container_runtime_init "$(read_config_value CONTAINER_FRONTEND auto)"
load_env_defaults "$project_dir/docker/images.env" FLUTTER_BUILD_IMAGE NGINX_IMAGE
network_name="$(resolve_network_name)"
container_name="$(read_config_value CONTAINER_NAME cashlenx-app)"
stop_grace_period="$(read_config_value WEB_STOP_GRACE_PERIOD 15s)"
compose_args=(--env-file "$env_file" -f "$compose_file")
compose_preflight "${compose_args[@]}"
stop_result=0
stop_container_bounded "$container_name" "$stop_grace_period" || stop_result=$?
# Keep the built image and any current or future persistent volumes.
compose "${compose_args[@]}" down --remove-orphans
remove_network_if_unused "$network_name"
exit "$stop_result"
