#!/bin/bash
# Host prerequisites: podman available, repos where expected, no config landmines.
. "$(dirname "$0")/lib.sh"
echo "00-prereqs"

check "podman is installed and runnable" podman info
if podman info >/dev/null 2>&1; then
    ver="$(podman version --format '{{.Client.Version}}' 2>/dev/null | cut -d. -f1)"
    if [ -n "$ver" ] && [ "$ver" -ge 4 ]; then
        ok "podman major version >= 4 ($ver)"
    else
        fail "podman major version >= 4 (got '$ver')"
    fi
fi

check "curl is installed" command -v curl
check "pgeu-system repo at $PGEU_DIR" test -f "$PGEU_DIR/manage.py"
check "pgusweb skin repo at $PGUSWEB_DIR" test -f "$PGUSWEB_DIR/code/skin_settings.py"
check "skin media present" test -f "$PGUSWEB_DIR/media/pgus/css/main.css"

# A stray local_settings.py loads at settings stage 2 and fights the
# module-based config (and swallows its own ImportErrors). Must not exist.
if [ -e "$PGEU_DIR/postgresqleu/local_settings.py" ]; then
    fail "postgresqleu/local_settings.py exists (remove it; podman flow uses pgeu_system_*_settings modules)"
else
    ok "no stray postgresqleu/local_settings.py"
fi

# Leftover symlink hack from the devcontainer-era skin setup.
if [ -L "$PGEU_DIR/media/pgus" ]; then
    fail "media/pgus symlink exists (remove it; uwsgi static-map serves skin media now)"
else
    ok "no media/pgus symlink hack"
fi

finish
