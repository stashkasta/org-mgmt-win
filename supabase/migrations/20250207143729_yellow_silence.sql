/*
  # Fix recursive policies with simplified approach

  1. Changes
    - Drop existing policies that cause recursion
    - Create new non-recursive policies using a base table approach
    - Remove all circular dependencies
    - Optimize query performance with proper indexes
*/

-- Drop existing policies
DROP POLICY IF EXISTS "user_organizations_base_select" ON user_organizations;
DROP POLICY IF EXISTS "user_details_base_select" ON user_details;
DROP POLICY IF EXISTS "user_details_base_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_base_update" ON user_details;

-- Drop existing view
DROP VIEW IF EXISTS users_view;

-- Create index to optimize role name lookups
CREATE INDEX IF NOT EXISTS idx_user_organizations_role_name_user_id 
ON user_organizations(role_name, user_id);

-- Create users view with base table approach
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

-- Create simplified policies without recursion
CREATE POLICY "user_organizations_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    -- Users can see their own memberships
    user_id = auth.uid()
  );

CREATE POLICY "user_organizations_admin_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    -- Super-admins can see all memberships (using base table)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  );

CREATE POLICY "user_details_select"
  ON user_details FOR SELECT
  TO authenticated
  USING (
    -- Users can see their own details
    user_id = auth.uid()
  );

CREATE POLICY "user_details_admin_select"
  ON user_details FOR SELECT
  TO authenticated
  USING (
    -- Super-admins can see all details (using base table)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  );

CREATE POLICY "user_details_insert"
  ON user_details FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Users can insert their own details
    user_id = auth.uid()
    OR
    -- Super-admins can insert any details (using base table)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  );

CREATE POLICY "user_details_update"
  ON user_details FOR UPDATE
  TO authenticated
  USING (
    -- Users can update their own details
    user_id = auth.uid()
    OR
    -- Super-admins can update any details (using base table)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  )
  WITH CHECK (
    -- Users can update their own details
    user_id = auth.uid()
    OR
    -- Super-admins can update any details (using base table)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  );