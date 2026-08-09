#!/bin/bash
# uwsgi answers HTTP on the published port.
. "$(dirname "$0")/lib.sh"
echo "40-http"

check_http "GET / (homepage)" 200 "$BASE_URL/"

# Django is behind it, not a static file server: a dynamic 404 route.
got="$(http_status "$BASE_URL/this-page-does-not-exist-xyz/")"
if [ "$got" = "404" ]; then
    ok "unknown URL returns 404 [$got]"
else
    fail "unknown URL returns 404 [got $got]"
fi

finish
