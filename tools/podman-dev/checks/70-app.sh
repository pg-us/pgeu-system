#!/bin/bash
# Application-level sanity: admin reachable, seeded superuser can authenticate.
. "$(dirname "$0")/lib.sh"
echo "70-app"

# /admin/ should redirect an anonymous user to a login page (302), or 200.
got="$(http_status "$BASE_URL/admin/")"
case "$got" in
    200|301|302) ok "GET /admin/ reachable [$got]" ;;
    *)           fail "GET /admin/ reachable [got $got]" ;;
esac

# Superuser exists and password matches (plain Django auth — community auth
# must be disabled in dev via pgeu_system_override_settings).
if app_exec python3 /app/manage.py shell -c "
from django.contrib.auth import authenticate
import sys
u = authenticate(username='testuser', password='testpass')
sys.exit(0 if (u is not None and u.is_superuser) else 1)
" >/dev/null 2>&1; then
    ok "superuser testuser/testpass authenticates"
else
    fail "superuser testuser/testpass authenticates"
fi

# Settings really came from the module scheme, with dev overrides applied last.
if app_exec python3 /app/manage.py shell -c "
from django.conf import settings
import sys
assert settings.SYSTEM_SKIN_DIRECTORY == '/skin', settings.SYSTEM_SKIN_DIRECTORY
assert settings.SITEBASE.startswith('http://localhost'), settings.SITEBASE
assert settings.DEBUG is True
sys.exit(0)
" >/dev/null 2>&1; then
    ok "settings: skin dir /skin, dev SITEBASE beats skin, DEBUG on"
else
    fail "settings: skin dir /skin, dev SITEBASE beats skin, DEBUG on"
fi

finish
