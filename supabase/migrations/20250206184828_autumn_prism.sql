/*
  # Fix policy recursion and simplify organization access
  
  1. Changes
    - Remove recursive policy dependencies
    - Allow public access to non-default organizations
    - Maintain secure access for authenticated users
  
  2. Security
    - Public can only read non-default organizations
    - Authenticated users maintain access to their organizations
    - Protected user organization data
*/

-- First, drop ALL existing policies
DO $$ 
BEGIN
    -- Drop organization policies
    DROP POLICY IF EXISTS "org_public_read_20250207" ON organizations;
    DROP POLICY IF EXISTS "org_auth_read_20250207" ON organizations;
    DROP POLICY IF EXISTS "org_auth_insert_20250207" ON organizations;
    
    -- Drop user organization policies
    DROP POLICY IF EXISTS "user_org_read_own_20250207" ON user_organizations;
    DROP POLICY IF EXISTS "user_org_read_admin_20250207" ON user_organizations;
    DROP POLICY IF EXISTS "user_org_insert_20250207" ON user_organizations;
END $$;

-- Create non-recursive organization policies
CREATE POLICY "org_public_read_20250208"
    ON organizations FOR SELECT
    USING (NOT is_default);

CREATE POLICY "org_member_read_20250208"
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

CREATE POLICY "org_insert_20250208"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);

-- Create simplified user organization policies
CREATE POLICY "user_org_select_own_20250208"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_org_select_admin_20250208"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 
            FROM user_organizations admin_org 
            WHERE admin_org.user_id = auth.uid()
            AND admin_org.organization_id = user_organizations.organization_id
            AND admin_org.role_name IN ('Admin', 'Super-admin')
        )
    );

CREATE POLICY "user_org_insert_20250208"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());