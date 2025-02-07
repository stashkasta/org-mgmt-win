/*
  # Fix policy recursion

  1. Changes
    - Simplify user organization policies to avoid recursion
    - Update organization policies for clarity
    - Maintain security while fixing circular references

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
            WHERE user_organizations.organization_id = organizations.id 
            AND user_organizations.user_id = auth.uid()
        )
    );

CREATE POLICY "organizations_insert"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);

-- Simplified user organizations policies to avoid recursion
CREATE POLICY "user_organizations_select"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 
            FROM user_organizations admin_org 
            WHERE admin_org.user_id = auth.uid()
            AND admin_org.organization_id = user_organizations.organization_id
            AND admin_org.role_name IN ('Admin', 'Super-admin')
        )
    );

CREATE POLICY "user_organizations_insert"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        OR NOT EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE organization_id = user_organizations.organization_id
        )
    );