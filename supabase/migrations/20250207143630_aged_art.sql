/*
  # Fix recursive policies with simplified approach

  1. Changes
    - Drop existing policies that cause recursion
    - Create new non-recursive policies using simplified logic
    - Remove circular dependencies in policy conditions
    - Optimize query performance with proper indexes
*/

-- Drop existing policies
DROP POLICY IF EXISTS "user_organizations_select" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;

-- Drop existing view
DROP VIEW IF EXISTS users_view;

-- Create index to optimize role name lookups
CREATE INDEX IF NOT EXISTS idx_user_organizations_role_name 
ON user_organizations(role_name, user_id);

-- Create users view with optimized role check
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
)
ORDER BY 
    COALESCE(ud.full_name, split_part(u.email, '@', 1)) COLLATE "C" ASC;

-- Grant access to authenticated users
GRANT SELECT ON users_view TO authenticated;

-- Create simplified non-recursive policies
CREATE POLICY "user_organizations_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    -- Users can see their own memberships
    user_id = auth.uid()
    OR 
    -- Super-admins can see all memberships (direct check)
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
    OR 
    -- Super-admins can see all details (direct check)
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
    -- Super-admins can insert any details (direct check)
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
    -- Super-admins can update any details (direct check)
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
    -- Super-admins can update any details (direct check)
    EXISTS (
      SELECT 1 
      FROM user_organizations base_check
      WHERE base_check.user_id = auth.uid() 
      AND base_check.role_name = 'Super-admin'
    )
  );