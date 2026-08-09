#!/bin/bash
# Database is ready, initialized, and migrated.
. "$(dirname "$0")/lib.sh"
echo "30-db"

check "postgres accepts connections" db_exec pg_isready -U "$DBUSER" -d "$DBNAME"

psql_q() { db_exec psql -U "$DBUSER" -d "$DBNAME" -At -c "$1"; }

if [ "$(psql_q 'SELECT 1' 2>/dev/null)" = "1" ]; then
    ok "psql query as $DBUSER works"
else
    fail "psql query as $DBUSER works"
fi

if [ "$(psql_q "SELECT count(*) FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='pgcrypto' AND n.nspname='pgcrypto'" 2>/dev/null)" = "1" ]; then
    ok "pgcrypto extension installed in schema pgcrypto"
else
    fail "pgcrypto extension installed in schema pgcrypto"
fi

# Django side: connection settings correct and no unapplied migrations.
check "manage.py migrate --check (all migrations applied)" \
    app_exec python3 /app/manage.py migrate --check

finish
