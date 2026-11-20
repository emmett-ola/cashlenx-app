#!/usr/bin/env bash
# Single test entry point for the App.
#
# Runs the Flutter unit and widget suite. Browser acceptance, container
# journeys and whole-product acceptance are separate entry points
# (scripts/browser-acceptance.sh and the workspace-level gates), because they
# need a running API and disposable data.
#
# Extra arguments are forwarded to `flutter test`, for example one file:
#   scripts/test.sh test/features/profile/presentation/pages/profile_page_test.dart
#
# `flutter test` may rewrite host entries in pubspec.lock; restore unrelated
# lockfile churn before committing.
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$project_dir"

exec flutter test "$@"
