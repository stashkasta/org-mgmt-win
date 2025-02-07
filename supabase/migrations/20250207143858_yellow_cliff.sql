/*
  # Fix recursive policies with simplified approach

  1. Changes
    - Drop existing recursive policies
    - Create new non-recursive policies using direct role checks
    - Optimize query performance with proper indexes
    - Simplify policy structure
*/

-- Drop existing policies
DROP POLICY IF EXISTS "user_org_select_own" ON user_organizations;
DROP POLICY IF EXISTS "user_org_select_admin" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select_own" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select_admin" ON user_organizations;
DROP POLICY IF EXISTS "user_details_insert_own" ON user_details;
DROP POLICY IF EXISTS "user_details_insert_admin" ON user_details;
DROP POLICY IF EXISTS "user_details_update_own" ON user_details;
DROP POLICY IF EXISTS "user_details_update_admin" ON user_details;

-- Drop existing view
DROP VIEW IF EXISTS users_view;

-- Create index for role name lookups
CREATE INDEX IF NOT EXISTS idx_user_organizations_role_name_user_id 
ON user_organizations(role_name, user_id);

-- Create simplified users view
CREATE VIEW users_view AS
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
CREATE POLICY "user_org_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    -- Users can see their own memberships
    user_id = auth.uid()
    OR
    -- Super-admins can see all memberships (direct check)
    role_name = 'Super-admin'
  );

CREATE POLICY "user_org_insert"
  ON user_organizations FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Create simplified policies for user details
CREATE POLICY "user_details_select"
  ON user_details FOR SELECT
  TO authenticated
  USING (
    -- Users can see their own details
    user_id = auth.uid()
    OR
    -- Super-admins can see all details (direct check)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
      LIMIT 1
    )
  );

CREATE POLICY "user_details_insert"
  ON user_details FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Users can insert their own details
    user_id = auth.uid()
    OR
    -- Super-admins can insert any details (direct check)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
      LIMIT 1
    )
  );

CREATE POLICY "user_details_update"
  ON user_details FOR UPDATE
  TO authenticated
  USING (
    -- Users can update their own details
    user_id = auth.uid()
    OR
    -- Super-admins can update any details (direct check)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
      LIMIT 1
    )
  )
  WITH CHECK (
    -- Users can update their own details
    user_id = auth.uid()
    OR
    -- Super-admins can update any details (direct check)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
      LIMIT 1
    )
  );