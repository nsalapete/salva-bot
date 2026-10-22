#!/bin/bash
# Create the roles used by the inventory API (PostgREST).
# Runs automatically after 01-schema.sql on a fresh database volume.
# The login password comes from INVENTORY_API_DB_PASSWORD in .env, never from Git.
set -e

psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
     -v api_password="$INVENTORY_API_DB_PASSWORD" <<'EOSQL'
-- What the API may do: read the catalogue and reserve stock, nothing else
CREATE ROLE web_anon NOLOGIN;
GRANT USAGE ON SCHEMA public TO web_anon;
GRANT SELECT ON products TO web_anon;
GRANT EXECUTE ON FUNCTION reserve_stock(integer, text, integer) TO web_anon;

-- The login PostgREST connects with; its only power is to act as web_anon
CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD :'api_password';
GRANT web_anon TO authenticator;
EOSQL
