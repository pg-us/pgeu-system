#!/bin/bash
# Follow logs: ./logs.sh [app|db]  (default: app)
set -u
case "${1:-app}" in
    app) podman logs -f pgeu-app ;;
    db)  podman logs -f pgeu-db ;;
    *)   echo "usage: $0 [app|db]" >&2; exit 2 ;;
esac
