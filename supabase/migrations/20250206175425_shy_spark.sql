/*
  # Update organization access policies for public access

  1. Changes
    - Allow public access to non-default organizations
    - Maintain existing authenticated user policies
    
  2. Security
    - Only expose non-sensitive organization data to public
    - Maintain existing security for authenticated operations
*/

-- Drop existing organization policies
DROP POLICY IF EXISTS "allow_read_all_organizations" ON organizations;
DROP POLICY IF EXISTS "allow_insert_organization" ON organizations;

-- Create new organization policies
CREATE POLICY "allow_public_read_organizations"
    ON organizations FOR SELECT
    USING (NOT is_default);

CREATE POLICY "allow_auth_read_organizations"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "allow_insert_organization"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);