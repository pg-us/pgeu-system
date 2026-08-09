#!/bin/bash
# Full reset: remove pod AND the database volume. Destroys all dev data.
set -u
podman pod rm -f "${PGEU_POD:-pgeu-dev}" 2>/dev/null
podman volume rm pgeu-pgdata 2>/dev/null
echo "pod and pgeu-pgdata volume removed; re-run up.sh for a fresh instance"
