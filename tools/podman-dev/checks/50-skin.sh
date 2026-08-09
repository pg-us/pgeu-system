#!/bin/bash
# The pgusweb skin is actually active: templates, pages catch-all, skin URLs.
. "$(dirname "$0")/lib.sh"
echo "50-skin"

# Skin templates render: pgus asset references only exist in pgusweb templates.
body="$(curl -s --max-time 10 "$BASE_URL/" 2>/dev/null)"
if printf '%s' "$body" | grep -q '/media/pgus/'; then
    ok "homepage rendered from skin templates (references /media/pgus/)"
else
    fail "homepage rendered from skin templates (no /media/pgus/ reference — skin not active?)"
fi

# Skin static pages via the static_fallback catch-all view.
check_http "GET /aboutus/ (skin pages/aboutus.html)" 200 "$BASE_URL/aboutus/"
check_http "GET /team/ (skin pages/team.html)" 200 "$BASE_URL/team/"

# skin_urls.PRELOAD_URLS loaded: /diversity/ permanent-redirects.
got="$(http_status "$BASE_URL/diversity/")"
loc="$(curl -s -o /dev/null -w '%{redirect_url}' --max-time 10 "$BASE_URL/diversity/" 2>/dev/null)"
if [ "$got" = "301" ] && printf '%s' "$loc" | grep -q '/community_development/'; then
    ok "skin_urls active: /diversity/ 301 -> /community_development/"
else
    fail "skin_urls active: /diversity/ [got $got -> ${loc:-none}]"
fi

finish
