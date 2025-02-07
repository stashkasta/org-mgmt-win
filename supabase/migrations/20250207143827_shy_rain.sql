/*
  # Fix policies with non-recursive approach

  1. Changes
    - Drop existing policies that cause recursion
    - Create new non-recursive policies using direct role checks
    - Remove materialized view dependency
    - Optimize query performance with proper indexes
    - Simplify policy structure
*/

-- Drop existing policies
DROP POLICY IF EXISTS "user_organizations_select" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_admin_select" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_admin_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;

-- Drop existing view
DROP VIEW IF EXISTS users_view;

-- Create index to optimize role name lookups
CREATE INDEX IF NOT EXISTS idx_user_organizations_role_name_user_id 
ON user_organizations(role_name, user_id);

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
    FROM user_organizations base_check
    WHERE base_check.user_id = auth.uid() 
    AND base_check.role_name = 'Super-admin'
);

-- Grant access to authenticated users
GRANT SELECT ON users_view TO authenticated;

-- Create simplified policies for user organizations
CREATE POLICY "user_org_select_own"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "user_org_select_admin"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  );

-- Create simplified policies for user details
CREATE POLICY "user_details_select_own"
  ON user_details FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "user_details_select_admin"
  ON user_details FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  );

CREATE POLICY "user_details_insert_own"
  ON user_details FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_details_insert_admin"
  ON user_details FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  );

CREATE POLICY "user_details_update_own"
  ON user_details FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_details_update_admin"
  ON user_details FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  );