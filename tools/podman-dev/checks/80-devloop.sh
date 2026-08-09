#!/bin/bash
# Developer-loop ergonomics: bind mounts are writable both ways with sane
# ownership, tree stays clean, code reload is configured.
. "$(dirname "$0")/lib.sh"
echo "80-devloop"

# Files created inside the container land on the host owned by the host user
# (default rootless mapping: container root == host user).
marker="tools/podman-dev/.write-test-$$"
if app_exec touch "/app/$marker" 2>/dev/null; then
    if [ -f "$PGEU_DIR/$marker" ] && [ -O "$PGEU_DIR/$marker" ]; then
        ok "container write to /app appears on host, owned by $USER"
    else
        fail "container write to /app appears on host, owned by $USER"
    fi
    rm -f "$PGEU_DIR/$marker"
    app_exec rm -f "/app/$marker" 2>/dev/null
else
    fail "container can write to /app bind mount"
fi

# The podman flow must not dirty the source tree with generated files.
for f in postgresqleu/local_settings.py devserver-uwsgi.ini python; do
    if [ -e "$PGEU_DIR/$f" ]; then
        fail "generated file $f present in tree (flow must not create it)"
    else
        ok "no generated $f in tree"
    fi
done

# Auto-reload configured so edits take effect without pod restarts.
if app_exec grep -q 'py-autoreload' /app/tools/podman-dev/uwsgi.ini 2>/dev/null; then
    ok "uwsgi py-autoreload enabled"
else
    fail "uwsgi py-autoreload enabled"
fi

finish
