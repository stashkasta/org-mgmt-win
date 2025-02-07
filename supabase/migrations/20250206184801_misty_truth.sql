/*
  # Update organization access policies
  
  1. Changes
    - Allow public access to non-default organizations
    - Maintain authenticated user access to their organizations
    - Ensure proper security for user organizations
  
  2. Security
    - Public can only read non-default organizations
    - Authenticated users maintain access to their organizations
    - Protected user organization data
*/

-- First, drop ALL existing policies to avoid conflicts
DO $$ 
BEGIN
    -- Drop organization policies if they exist
    DROP POLICY IF EXISTS "org_public_read_20250206" ON organizations;
    DROP POLICY IF EXISTS "org_auth_read_20250206" ON organizations;
    DROP POLICY IF EXISTS "org_auth_insert_20250206" ON organizations;
    DROP POLICY IF EXISTS "organizations_public_select" ON organizations;
    DROP POLICY IF EXISTS "organizations_auth_select" ON organizations;
    DROP POLICY IF EXISTS "organizations_insert" ON organizations;
    
    -- Drop user organization policies if they exist
    DROP POLICY IF EXISTS "user_org_read_own_20250206" ON user_organizations;
    DROP POLICY IF EXISTS "user_org_read_admin_20250206" ON user_organizations;
    DROP POLICY IF EXISTS "user_org_insert_20250206" ON user_organizations;
END $$;

-- Create public access policy for non-default organizations
CREATE POLICY "org_public_read_20250207"
    ON organizations FOR SELECT
    USING (NOT is_default);

-- Create authenticated access policy for member organizations
CREATE POLICY "org_auth_read_20250207"
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

-- Maintain insert policy for authenticated users
CREATE POLICY "org_auth_insert_20250207"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);

-- Update user organization policies to avoid recursion
CREATE POLICY "user_org_read_own_20250207"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_org_read_admin_20250207"
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

CREATE POLICY "user_org_insert_20250207"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());