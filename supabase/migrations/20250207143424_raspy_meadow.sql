/*
  # Fix materialized view permissions

  1. Changes
    - Drop existing policies that depend on the materialized view
    - Create materialized view with proper permissions
    - Recreate policies with proper access control
*/

-- First, drop dependent policies
DROP POLICY IF EXISTS "user_organizations_select" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;

-- Drop dependent view
DROP VIEW IF EXISTS users_view;

-- Drop existing materialized view
DROP MATERIALIZED VIEW IF EXISTS super_admin_users;

-- Create materialized view with proper permissions
CREATE MATERIALIZED VIEW super_admin_users AS
SELECT DISTINCT user_id
FROM user_organizations
WHERE role_name = 'Super-admin';

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_super_admin_users ON super_admin_users(user_id);

-- Grant permissions to authenticated users
GRANT SELECT ON super_admin_users TO authenticated;

-- Create function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_super_admin_users()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW super_admin_users;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to refresh the view
DROP TRIGGER IF EXISTS refresh_super_admin_users_trigger ON user_organizations;
CREATE TRIGGER refresh_super_admin_users_trigger
  AFTER INSERT OR UPDATE OR DELETE
  ON user_organizations
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_super_admin_users();

-- Recreate users view
CREATE OR REPLACE VIEW users_view WITH (security_barrier = true) AS
SELECT 
    u.id,
    u.email,
    u.email_confirmed_at,
    u.last_sign_in_at,
    COALESCE(ud.full_name, split_part(u.email, '@', 1)) as sort_name
FROM auth.users u
LEFT JOIN user_details ud ON u.id = ud.user_id
WHERE EXISTS (
    SELECT 1 
    FROM super_admin_users 
    WHERE user_id = auth.uid()
)
ORDER BY 
    COALESCE(ud.full_name, split_part(u.email, '@', 1)) COLLATE "C" ASC;

-- Grant access to authenticated users
GRANT SELECT ON users_view TO authenticated;

-- Recreate policies using the materialized view
CREATE POLICY "user_organizations_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "user_details_select"
  ON user_details FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "user_details_insert"
  ON user_details FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "user_details_update"
  ON user_details FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  );

-- Initial refresh of the materialized view
REFRESH MATERIALIZED VIEW super_admin_users;