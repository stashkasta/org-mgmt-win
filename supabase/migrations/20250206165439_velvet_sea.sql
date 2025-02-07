/*
  # Fix RLS policies for organization creation

  1. Changes
    - Drop existing organization policies
    - Create new simplified policies for organizations
    - Add explicit INSERT policies
    - Ensure proper access control for initial setup

  2. Security
    - Allow authenticated users to create organizations
    - Allow users to read organizations they belong to
    - Allow users to read default organization
    - Maintain proper access control for user details and memberships
*/

-- Drop existing organization policies
DROP POLICY IF EXISTS "allow_read_organizations" ON organizations;
DROP POLICY IF EXISTS "allow_read_member_organizations" ON organizations;
DROP POLICY IF EXISTS "allow_create_organizations" ON organizations;

-- Create new organization policies
CREATE POLICY "organizations_select_default"
    ON organizations FOR SELECT
    TO authenticated
    USING (is_default = true);

CREATE POLICY "organizations_select_member"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "organizations_insert"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Update user_organizations policies
DROP POLICY IF EXISTS "allow_create_user_organizations" ON user_organizations;
DROP POLICY IF EXISTS "allow_read_own_organizations" ON user_organizations;

CREATE POLICY "user_organizations_select"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_organizations_insert"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Update user_details policies
DROP POLICY IF EXISTS "allow_manage_user_details" ON user_details;
DROP POLICY IF EXISTS "allow_create_user_details" ON user_details;

CREATE POLICY "user_details_select"
    ON user_details FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_details_insert"
    ON user_details FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_details_update"
    ON user_details FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());