-- Create auth.jwt() stub as supabase_auth_admin so that:
--   1. The app schema (za_) can reference it during init.
--   2. GoTrue's own migration can CREATE OR REPLACE it (owner check passes).
--
-- This is needed because supabase/postgres does not ship auth.jwt() in its
-- bundled init SQL; GoTrue creates it during its own migration run, but by
-- then the app schema has already failed.  We create a compatible stub here.

SET ROLE supabase_auth_admin;

CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT
    coalesce(
      nullif(current_setting('request.jwt.claims', true), ''),
      nullif(current_setting('request.jwt.claim', true), '')
    )::jsonb
$$;

RESET ROLE;
