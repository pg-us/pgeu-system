#!/bin/bash
# Stop and remove the pod (keeps the pgeu-pgdata volume).
set -u
podman pod rm -f "${PGEU_POD:-pgeu-dev}"
