/*
  # Fix policy recursion with simplified access rules
  
  1. Changes
    - Remove all recursive policy dependencies
    - Simplify organization access rules
    - Separate public and authenticated access
  
  2. Security
    - Public can read non-default organizations
    - Authenticated users maintain secure access
    - Protected user organization data
*/

-- First, drop ALL existing policies
DO $$ 
BEGIN
    -- Drop organization policies
    DROP POLICY IF EXISTS "org_public_read_20250208" ON organizations;
    DROP POLICY IF EXISTS "org_member_read_20250208" ON organizations;
    DROP POLICY IF EXISTS "org_insert_20250208" ON organizations;
    
    -- Drop user organization policies
    DROP POLICY IF EXISTS "user_org_select_own_20250208" ON user_organizations;
    DROP POLICY IF EXISTS "user_org_select_admin_20250208" ON user_organizations;
    DROP POLICY IF EXISTS "user_org_insert_20250208" ON user_organizations;
END $$;

-- Create public organization access
CREATE POLICY "org_public_read_20250209"
    ON organizations FOR SELECT
    USING (NOT is_default);

-- Create member organization access (no recursion)
CREATE POLICY "org_member_read_20250209"
    ON organizations FOR SELECT
    TO authenticated
    USING (is_default = true);

-- Allow organization creation
CREATE POLICY "org_insert_20250209"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);

-- Create basic user organization policies
CREATE POLICY "user_org_select_20250209"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_org_insert_20250209"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());