# Shared helpers for podman-dev checks. Sourced, not executed.

set -u

APP="${PGEU_APP:-pgeu-app}"
DB="${PGEU_DB:-pgeu-db}"
BASE_URL="${PGEU_BASE_URL:-http://localhost:8012}"
IMAGE="${PGEU_IMAGE:-localhost/pgeu-dev-app}"
DBUSER="${PGEU_DBUSER:-postgresqleu}"
DBNAME="${PGEU_DBNAME:-postgresqleu}"

# Repo roots: checks live in <pgeu-system>/tools/podman-dev/checks
PGEU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PGUSWEB_DIR="${PGUSWEB_DIR:-$(cd "$PGEU_DIR/.." && pwd)/pgusweb}"

_fails=0

ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; _fails=$((_fails + 1)); }

# check <description> <command...>  — runs command silently, records result
check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi
}

# http_status <url> — prints status code (000 on connection failure)
http_status() {
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null)"
    printf '%s' "${code:-000}"
}

# check_http <description> <expected-status> <url>
check_http() {
    local desc="$1" want="$2" url="$3" got
    got="$(http_status "$url")"
    if [ "$got" = "$want" ]; then
        ok "$desc [$got]"
    else
        fail "$desc [want $want, got $got] $url"
    fi
}

# app_exec <cmd...> — run inside the app container
app_exec() { podman exec "$APP" "$@"; }
db_exec()  { podman exec "$DB" "$@"; }

finish() {
    if [ "$_fails" -gt 0 ]; then
        printf 'RESULT: FAIL (%d)\n' "$_fails"
        exit 1
    fi
    printf 'RESULT: PASS\n'
    exit 0
}
