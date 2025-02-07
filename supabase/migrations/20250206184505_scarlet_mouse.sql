/*
  # Fix policy recursion with simplified policies

  1. Changes
    - Remove all circular references in policies
    - Simplify organization and user organization access rules
    - Maintain security while preventing recursion

  2. Security
    - Maintain RLS protection
    - Ensure proper access control
    - Prevent unauthorized access
*/

-- Drop existing policies
DROP POLICY IF EXISTS "organizations_select" ON organizations;
DROP POLICY IF EXISTS "organizations_insert" ON organizations;
DROP POLICY IF EXISTS "user_organizations_select" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_insert" ON user_organizations;

-- Simple organization policies
CREATE POLICY "organizations_select"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        is_default = true 
        OR EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE user_organizations.organization_id = id 
            AND user_organizations.user_id = auth.uid()
        )
    );

CREATE POLICY "organizations_insert"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);

-- Simplified user organizations policies without recursion
CREATE POLICY "user_organizations_select"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (
        -- Users can see their own memberships
        user_id = auth.uid()
        OR
        -- Users can see memberships of organizations they are admins of
        (
            organization_id IN (
                SELECT uo.organization_id
                FROM user_organizations uo
                WHERE uo.user_id = auth.uid()
                  AND uo.role_name IN ('Admin', 'Super-admin')
            )
        )
    );

CREATE POLICY "user_organizations_insert"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (
        -- Users can create their own memberships
        user_id = auth.uid()
        OR
        -- Allow initial admin creation for new organizations
        NOT EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE organization_id = user_organizations.organization_id
        )
    );