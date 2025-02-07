/*
  # Update organization policies for public access
  
  1. Changes
    - Allow public access to non-default organizations
    - Maintain existing authenticated user access
    - Keep insert restrictions for authenticated users only
  
  2. Security
    - Public can only read non-default organizations
    - Authenticated users maintain full access to their organizations
    - Insert operations still require authentication
*/

-- Drop existing organization policies
DROP POLICY IF EXISTS "organizations_select" ON organizations;
DROP POLICY IF EXISTS "organizations_insert" ON organizations;

-- Create public read policy for non-default organizations
CREATE POLICY "organizations_public_select"
    ON organizations FOR SELECT
    USING (NOT is_default);

-- Create authenticated user policy for all accessible organizations
CREATE POLICY "organizations_auth_select"
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

-- Keep insert policy for authenticated users only
CREATE POLICY "organizations_insert"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);