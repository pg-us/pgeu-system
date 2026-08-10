#!/bin/bash
# App image sanity: catches "builds fine but a runtime-only import is broken"
# after dependency changes. cairosvg/reportlab/fonts are only exercised at
# badge/invoice generation time, which no HTTP check reaches.
. "$(dirname "$0")/lib.sh"
echo "10-image"

check "image $IMAGE exists" podman image exists "$IMAGE"

if podman image exists "$IMAGE"; then
    run() { podman run --rm --entrypoint "" "$IMAGE" "$@"; }
    check "uwsgi in image" run uwsgi --version
    check "django importable" run python3 -c "import django"
    check "psycopg2 importable" run python3 -c "import psycopg2"
    check "jinja2 importable" run python3 -c "import jinja2"
    check "PIL importable" run python3 -c "import PIL"
    check "reportlab importable" run python3 -c "import reportlab"
    check "cairosvg importable (needs libcairo2)" run python3 -c "import cairosvg"
    check "qrcode importable" run python3 -c "import qrcode"
    check "pg_isready in image (entrypoint wait-for-db)" run which pg_isready
    # DejaVu must be reachable at the default FONTROOT (image symlink) or
    # FONTROOT must be overridden in the podman-dev config modules.
    if run test -e /usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf \
       || grep -qs '^FONTROOT' "$PGEU_DIR"/tools/podman-dev/config/*.py; then
        ok "DejaVu fonts reachable (FONTROOT default or override)"
    else
        fail "DejaVu fonts reachable (FONTROOT default or override)"
    fi
fi

finish
