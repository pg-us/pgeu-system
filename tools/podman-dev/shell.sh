#!/bin/bash
# Shell helpers: ./shell.sh [app|db|django|psql]  (default: app)
set -u
case "${1:-app}" in
    app)    exec podman exec -it pgeu-app bash ;;
    db)     exec podman exec -it pgeu-db bash ;;
    django) exec podman exec -it pgeu-app python3 /app/manage.py shell ;;
    psql)   exec podman exec -it pgeu-db psql -U postgresqleu postgresqleu ;;
    *)      echo "usage: $0 [app|db|django|psql]" >&2; exit 2 ;;
esac
