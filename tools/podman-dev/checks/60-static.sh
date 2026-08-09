#!/bin/bash
# All three static-map trees are served by uwsgi (no symlink hack, no runserver).
. "$(dirname "$0")/lib.sh"
echo "60-static"

# Core pgeu-system assets: /media -> pgeu-system/media
check_http "core static: /media/css/bootstrap.min.css" 200 "$BASE_URL/media/css/bootstrap.min.css"

# Skin assets: /media/pgus -> pgusweb/media/pgus (the symlink-hack replacement)
check_http "skin static: /media/pgus/css/main.css" 200 "$BASE_URL/media/pgus/css/main.css"
check_http "skin static: /media/pgus/css/pgus.css" 200 "$BASE_URL/media/pgus/css/pgus.css"
check_http "skin static: favicon" 200 "$BASE_URL/media/pgus/favicon.ico"

# Non-trivial content, not an error page.
size="$(curl -s --max-time 10 "$BASE_URL/media/pgus/css/main.css" 2>/dev/null | wc -c)"
if [ "${size:-0}" -gt 1000 ]; then
    ok "skin main.css has real content ($size bytes)"
else
    fail "skin main.css has real content (got $size bytes)"
fi

# Django admin assets: /media/admin -> django/contrib/admin/static/admin
check_http "admin static: /media/admin/css/base.css" 200 "$BASE_URL/media/admin/css/base.css"

# Correct MIME type (needs media-types in the image, or browsers ignore the CSS)
ctype="$(curl -s -I --max-time 10 "$BASE_URL/media/pgus/css/main.css" 2>/dev/null | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type" {print $2}')"
if [ "$ctype" = "text/css" ]; then
    ok "css served as text/css"
else
    fail "css served as text/css (got '${ctype:-none}')"
fi

finish
