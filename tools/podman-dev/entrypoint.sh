#!/bin/bash
# App container entrypoint: wait for the in-pod database, migrate,
# seed a superuser (idempotent), then run uwsgi.
set -e

DBHOST="${PGEU_DBHOST:-127.0.0.1}"
DBUSER="${PGEU_DBUSER:-postgresqleu}"
DBNAME="${PGEU_DBNAME:-postgresqleu}"

echo "waiting for postgres at $DBHOST..."
for i in $(seq 1 60); do
    pg_isready -q -h "$DBHOST" -U "$DBUSER" -d "$DBNAME" && break
    [ "$i" = 60 ] && { echo "database never became ready" >&2; exit 1; }
    sleep 1
done

cd /app
python3 manage.py migrate --noinput

# Uses DJANGO_SUPERUSER_{USERNAME,PASSWORD,EMAIL}; fails harmlessly if it exists.
if [ -n "${DJANGO_SUPERUSER_USERNAME:-}" ]; then
    python3 manage.py createsuperuser --noinput 2>/dev/null \
        || echo "superuser ${DJANGO_SUPERUSER_USERNAME} already exists"
fi

exec uwsgi --ini /app/tools/podman-dev/uwsgi.ini
