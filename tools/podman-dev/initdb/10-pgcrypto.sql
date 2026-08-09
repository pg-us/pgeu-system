-- Runs once on first initialization of the pgeu-pgdata volume,
-- against $POSTGRES_DB as the $POSTGRES_USER superuser.
CREATE SCHEMA pgcrypto;
CREATE EXTENSION pgcrypto SCHEMA pgcrypto;
GRANT USAGE ON SCHEMA pgcrypto TO PUBLIC;
