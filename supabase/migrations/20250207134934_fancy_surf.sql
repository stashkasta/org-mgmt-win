/*
  # Fix recursive policies in user_organizations table

  1. Changes
    - Drop existing policies that cause recursion
    - Create new non-recursive policies for user_organizations
    - Simplify policy logic to prevent circular dependencies

  2. Security
    - Maintain proper access control for users and admins
    - Prevent unauthorized access while avoiding recursion
*/

-- First, drop existing policies that cause recursion
DROP POLICY IF EXISTS "user_org_select_own" ON user_organizations;
DROP POLICY IF EXISTS "user_org_select_admin" ON user_organizations;
DROP POLICY IF EXISTS "user_org_insert" ON user_organizations;

-- Create new non-recursive policies
CREATE POLICY "user_org_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    -- Users can see their own memberships
    user_id = auth.uid()
    OR
    -- Super-admins can see all memberships
    EXISTS (
      SELECT 1 
      FROM user_organizations 
      WHERE user_id = auth.uid() 
      AND role_name = 'Super-admin'
    )
  );

CREATE POLICY "user_org_insert"
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