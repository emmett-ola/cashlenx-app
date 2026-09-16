# Container Build Contract

`images.env` is the tracked authority for base-image references. References are
pinned by digest so clean and warm builds use the same inputs. Update one pin in
an isolated change, build and verify the candidate image, and roll back by
reverting that change.

The root build context is allowlisted by `.dockerignore`. Environment files are
read by Compose only and are never sent to the builder. Flutter receives only
the public API settings as compile-time definitions; do not add credentials or
private configuration to those values.

Run `scripts/build.sh` to validate public configuration, build from the lockfile,
and verify required runtime files, OCI version/revision labels, and prohibited
file absence.

The repository-local lifecycle helper supports Docker Compose v2 and nerdctl
2.2+, performs capability checks before mutation, and derives the image
reference from `IMAGE_NAME` plus `IMAGE_TAG` without `config --images`.
