/*
  # Update organization access policies

  1. Changes
    - Simplify organization read policies
    - Allow authenticated users to read non-default organizations
    - Maintain security while enabling organization listing
    
  2. Security
    - Maintain RLS
    - Only allow reading of non-sensitive organization data
    - Preserve existing insert/update restrictions
*/

-- Drop existing organization policies
DROP POLICY IF EXISTS "organizations_read" ON organizations;
DROP POLICY IF EXISTS "organizations_read_default" ON organizations;
DROP POLICY IF EXISTS "organizations_read_member" ON organizations;
DROP POLICY IF EXISTS "organizations_insert" ON organizations;
DROP POLICY IF EXISTS "organizations_insert_auth" ON organizations;
DROP POLICY IF EXISTS "org_select" ON organizations;
DROP POLICY IF EXISTS "org_select_default" ON organizations;
DROP POLICY IF EXISTS "org_select_member" ON organizations;
DROP POLICY IF EXISTS "org_insert" ON organizations;

-- Create new organization policies
CREATE POLICY "allow_read_all_organizations"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        -- Allow reading all non-default organizations for joining
        -- and organizations the user is a member of
        NOT is_default 
        OR id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "allow_insert_organization"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);