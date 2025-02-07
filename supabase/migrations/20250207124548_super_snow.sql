/*
  # Allow public access to non-default organizations
  
  Changes:
  - Add policy to allow public access to non-default organizations
  - Update existing policies to ensure proper access
*/

-- Drop existing organization policies
DROP POLICY IF EXISTS "org_public_read_20250208" ON organizations;
DROP POLICY IF EXISTS "org_member_read_20250208" ON organizations;

-- Create public access policy for non-default organizations
CREATE POLICY "allow_public_read_organizations"
    ON organizations FOR SELECT
    USING (NOT is_default);

-- Create authenticated access policy for default organization
CREATE POLICY "allow_auth_read_default_org"
    ON organizations FOR SELECT
    TO authenticated
    USING (is_default = true);