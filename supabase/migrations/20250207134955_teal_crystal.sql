/*
  # Fix recursive policies with optimized structure

  1. Changes
    - Drop existing policies that may cause recursion
    - Create new non-recursive policies for user_organizations
    - Implement efficient Super-admin checks
    - Maintain proper access control

  2. Security
    - Ensure proper access control while avoiding recursion
    - Allow Super-admins to view all records
    - Allow users to view their own records
*/

-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "user_org_select" ON user_organizations;
DROP POLICY IF EXISTS "user_org_insert" ON user_organizations;

-- Create a materialized view for super admin users to avoid recursion
CREATE MATERIALIZED VIEW IF NOT EXISTS super_admin_users AS
SELECT DISTINCT user_id
FROM user_organizations
WHERE role_name = 'Super-admin';

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_super_admin_users ON super_admin_users(user_id);

-- Create function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_super_admin_users()
RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY super_admin_users;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to refresh the view when user_organizations changes
DROP TRIGGER IF EXISTS refresh_super_admin_users_trigger ON user_organizations;
CREATE TRIGGER refresh_super_admin_users_trigger
  AFTER INSERT OR UPDATE OR DELETE
  ON user_organizations
  FOR EACH STATEMENT
  EXECUTE FUNCTION refresh_super_admin_users();

-- Create new non-recursive policies
CREATE POLICY "user_organizations_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    -- Users can see their own memberships
    user_id = auth.uid()
    OR
    -- Super-admins can see all memberships (using materialized view)
    EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "user_organizations_insert"
  ON user_organizations FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Users can only insert their own memberships
    user_id = auth.uid()
    AND
    -- Verify role and organization exist
    EXISTS (SELECT 1 FROM roles WHERE id = role_id)
    AND EXISTS (SELECT 1 FROM organizations WHERE id = organization_id)
  );

-- Initial refresh of the materialized view
REFRESH MATERIALIZED VIEW super_admin_users;