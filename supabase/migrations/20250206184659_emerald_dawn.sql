/*
  # Fix organization and user organization policies
  
  1. Changes
    - Drop all existing policies first to avoid conflicts
    - Recreate policies with unique names
    - Ensure proper access control for organizations and memberships
  
  2. Security
    - Maintain proper access control
    - Allow public access to non-default organizations
    - Protect user organization data
*/

-- First, drop ALL existing policies to avoid conflicts
DO $$ 
BEGIN
    -- Drop organization policies if they exist
    DROP POLICY IF EXISTS "allow_public_read_organizations" ON organizations;
    DROP POLICY IF EXISTS "allow_auth_read_organizations" ON organizations;
    DROP POLICY IF EXISTS "allow_insert_organization" ON organizations;
    DROP POLICY IF EXISTS "organizations_public_select" ON organizations;
    DROP POLICY IF EXISTS "organizations_auth_select" ON organizations;
    DROP POLICY IF EXISTS "organizations_insert" ON organizations;
    
    -- Drop user organization policies if they exist
    DROP POLICY IF EXISTS "allow_read_own_memberships" ON user_organizations;
    DROP POLICY IF EXISTS "allow_read_organization_memberships" ON user_organizations;
    DROP POLICY IF EXISTS "allow_insert_membership" ON user_organizations;
    DROP POLICY IF EXISTS "user_organizations_select" ON user_organizations;
    DROP POLICY IF EXISTS "user_organizations_insert" ON user_organizations;
END $$;

-- Create organization policies with new unique names
CREATE POLICY "org_public_read_20250206"
    ON organizations FOR SELECT
    USING (NOT is_default);

CREATE POLICY "org_auth_read_20250206"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        is_default = true 
        OR id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "org_auth_insert_20250206"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);

-- Create user organization policies with new unique names
CREATE POLICY "user_org_read_own_20250206"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_org_read_admin_20250206"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM user_organizations base_memberships
            WHERE base_memberships.user_id = auth.uid()
            AND base_memberships.role_name IN ('Admin', 'Super-admin')
        )
    );

CREATE POLICY "user_org_insert_20250206"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());