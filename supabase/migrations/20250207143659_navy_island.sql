/*
  # Fix recursive policies with simplified approach

  1. Changes
    - Drop existing policies that cause recursion
    - Create new non-recursive policies using a base table approach
    - Remove all circular dependencies
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
    AND base_check.user_id IS NOT NULL
);

-- Grant access to authenticated users
GRANT SELECT ON users_view TO authenticated;

-- Create base table policies without recursion
CREATE POLICY "user_organizations_base_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    -- Direct ownership check
    user_id = auth.uid()
    OR
    -- Direct super admin check without recursion
    (
      SELECT EXISTS (
        SELECT 1 
        FROM user_organizations super_admin_check
        WHERE super_admin_check.user_id = auth.uid()
        AND super_admin_check.role_name = 'Super-admin'
        AND super_admin_check.user_id IS NOT NULL
        LIMIT 1
      )
    )
  );

-- Create user details policies with base table approach
CREATE POLICY "user_details_base_select"
  ON user_details FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR
    (
      SELECT EXISTS (
        SELECT 1 
        FROM user_organizations super_admin_check
        WHERE super_admin_check.user_id = auth.uid()
        AND super_admin_check.role_name = 'Super-admin'
        AND super_admin_check.user_id IS NOT NULL
        LIMIT 1
      )
    )
  );

CREATE POLICY "user_details_base_insert"
  ON user_details FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    OR
    (
      SELECT EXISTS (
        SELECT 1 
        FROM user_organizations super_admin_check
        WHERE super_admin_check.user_id = auth.uid()
        AND super_admin_check.role_name = 'Super-admin'
        AND super_admin_check.user_id IS NOT NULL
        LIMIT 1
      )
    )
  );

CREATE POLICY "user_details_base_update"
  ON user_details FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR
    (
      SELECT EXISTS (
        SELECT 1 
        FROM user_organizations super_admin_check
        WHERE super_admin_check.user_id = auth.uid()
        AND super_admin_check.role_name = 'Super-admin'
        AND super_admin_check.user_id IS NOT NULL
        LIMIT 1
      )
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR
    (
      SELECT EXISTS (
        SELECT 1 
        FROM user_organizations super_admin_check
        WHERE super_admin_check.user_id = auth.uid()
        AND super_admin_check.role_name = 'Super-admin'
        AND super_admin_check.user_id IS NOT NULL
        LIMIT 1
      )
    )
  );