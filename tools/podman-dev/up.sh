#!/bin/bash
# Build the app image and start (or restart) the pgeu-dev pod.
# Safe to re-run: keeps the database container/volume, recreates the app.
set -euo pipefail

cd "$(dirname "$0")/../.."
PGEU_DIR="$(pwd)"

# Machine-local overrides (untracked), e.g. PGEU_DBPORT when 5432 is taken.
[ -f tools/podman-dev/local.env ] && . tools/podman-dev/local.env
PGUSWEB_DIR="${PGUSWEB_DIR:-$(dirname "$PGEU_DIR")/pgusweb}"

POD="${PGEU_POD:-pgeu-dev}"
IMAGE="${PGEU_IMAGE:-localhost/pgeu-dev-app}"
DBPASS="${PGEU_DBPASS:-postgresqleu}"

[ -f "$PGUSWEB_DIR/code/skin_settings.py" ] \
    || { echo "pgusweb skin not found at $PGUSWEB_DIR (set PGUSWEB_DIR)" >&2; exit 1; }

podman build -t "$IMAGE" -f tools/podman-dev/Containerfile .

if ! podman pod exists "$POD"; then
    # 8012 = uwsgi http; PGEU_DBPORT = postgres for host tools (0 = don't publish)
    DBPORT="${PGEU_DBPORT:-5432}"
    PUBLISH_DB=()
    [ "$DBPORT" != "0" ] && PUBLISH_DB=(-p "127.0.0.1:$DBPORT:5432")
    podman pod create --name "$POD" -p 8012:8012 "${PUBLISH_DB[@]}"
fi

if ! podman container exists pgeu-db; then
    podman run -d --pod "$POD" --name pgeu-db \
        -e POSTGRES_USER=postgresqleu \
        -e POSTGRES_DB=postgresqleu \
        -e POSTGRES_PASSWORD="$DBPASS" \
        -v pgeu-pgdata:/var/lib/postgresql/data \
        -v "$PGEU_DIR/tools/podman-dev/initdb":/docker-entrypoint-initdb.d:ro,z \
        --health-cmd 'pg_isready -U postgresqleu -d postgresqleu' \
        --health-interval 5s \
        docker.io/library/postgres:17-bookworm
fi

podman rm -f pgeu-app >/dev/null 2>&1 || true
# No --userns=keep-id: in rootless podman, container root == the host user,
# so files created on the bind mounts are owned by you on the host.
podman run -d --pod "$POD" --name pgeu-app \
    -v "$PGEU_DIR":/app:z \
    -v "$PGUSWEB_DIR":/skin:z \
    -e PYTHONPATH=/app/tools/podman-dev/config \
    -e DJANGO_SUPERUSER_USERNAME="${PGEU_SUPERUSER:-testuser}" \
    -e DJANGO_SUPERUSER_PASSWORD="${PGEU_SUPERUSER_PASSWORD:-testpass}" \
    -e DJANGO_SUPERUSER_EMAIL="${PGEU_SUPERUSER_EMAIL:-admin@example.com}" \
    "$IMAGE"

echo
echo "pgeu-dev is starting: http://localhost:8012/  (admin: testuser/testpass)"
echo "logs:   tools/podman-dev/logs.sh"
echo "verify: tools/podman-dev/checks/run-checks.sh"
