/*
  # Fix materialized view permissions

  1. Changes
    - Drop existing policies and views
    - Create simplified policies without materialized view dependency
    - Use direct role check instead of materialized view
*/

-- Drop existing policies
DROP POLICY IF EXISTS "user_organizations_select" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;

-- Drop existing view
DROP VIEW IF EXISTS users_view;

-- Drop existing materialized view and related objects
DROP MATERIALIZED VIEW IF EXISTS super_admin_users;
DROP FUNCTION IF EXISTS refresh_super_admin_users() CASCADE;

-- Create users view with direct role check
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
    FROM user_organizations 
    WHERE user_id = auth.uid() 
    AND role_name = 'Super-admin'
)
ORDER BY 
    COALESCE(ud.full_name, split_part(u.email, '@', 1)) COLLATE "C" ASC;

-- Grant access to authenticated users
GRANT SELECT ON users_view TO authenticated;

-- Create simplified policies using direct role check
CREATE POLICY "user_organizations_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM user_organizations 
      WHERE user_id = auth.uid() 
      AND role_name = 'Super-admin'
    )
  );

CREATE POLICY "user_details_select"
  ON user_details FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM user_organizations 
      WHERE user_id = auth.uid() 
      AND role_name = 'Super-admin'
    )
  );

CREATE POLICY "user_details_insert"
  ON user_details FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM user_organizations 
      WHERE user_id = auth.uid() 
      AND role_name = 'Super-admin'
    )
  );

CREATE POLICY "user_details_update"
  ON user_details FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM user_organizations 
      WHERE user_id = auth.uid() 
      AND role_name = 'Super-admin'
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM user_organizations 
      WHERE user_id = auth.uid() 
      AND role_name = 'Super-admin'
    )
  );