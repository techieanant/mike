-- PostgREST role grants for the app schema.
-- This runs after 000_one_shot_schema.sql (init scripts are applied in
-- name order, and this file is mounted as 30_permissions.sql).
--
-- supabase/postgres creates the anon, authenticated, and service_role roles.
-- These grants let PostgREST query the public schema on behalf of those roles.

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Authenticated users and the service role can do everything; anon can read.
GRANT ALL   ON ALL TABLES    IN SCHEMA public TO authenticated, service_role;
GRANT SELECT ON ALL TABLES   IN SCHEMA public TO anon;
GRANT ALL   ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;
GRANT ALL   ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;

-- Ensure the same grants apply to tables created in the future.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO anon;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON SEQUENCES TO authenticated, service_role;
