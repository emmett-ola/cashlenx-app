#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"
. "$project_dir/scripts/lib/container_lifecycle.sh"
. "$project_dir/scripts/lib/flutter_config.sh"

for argument in "$@"; do
  case "$argument" in
    --dart-define|--dart-define=*|--dart-define-from-file|--dart-define-from-file=*)
      echo 'Configure public Flutter settings through ENV_FILE or explicit environment variables.' >&2
      exit 1
      ;;
  esac
done

env_file="$(resolve_env_file)"
load_flutter_config
exec flutter run "${flutter_defines[@]}" "$@"
