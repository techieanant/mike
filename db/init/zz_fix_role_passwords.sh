#!/bin/sh
# Fix role passwords for supabase internal roles.
# supabase/postgres init-scripts create supabase_auth_admin and authenticator
# without passwords; this script sets them to match POSTGRES_PASSWORD so that
# GoTrue (auth) and PostgREST (rest) can authenticate on startup.
set -e

PGPASSWORD="${POSTGRES_PASSWORD:-postgres}"

psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin -d postgres <<EOSQL
ALTER USER supabase_auth_admin WITH PASSWORD '$PGPASSWORD';
ALTER USER authenticator WITH PASSWORD '$PGPASSWORD';
ALTER USER supabase_storage_admin WITH PASSWORD '$PGPASSWORD';
EOSQL
