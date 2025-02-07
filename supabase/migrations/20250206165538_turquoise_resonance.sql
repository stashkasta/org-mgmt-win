/*
  # Fix organization creation policies

  1. Changes
    - Drop and recreate all organization-related policies
    - Simplify policy structure
    - Add explicit policies for all required operations
    - Ensure proper access for initial setup

  2. Security
    - Allow authenticated users to create organizations
    - Maintain proper access control for existing operations
*/

-- Drop all existing policies
DROP POLICY IF EXISTS "organizations_select_default" ON organizations;
DROP POLICY IF EXISTS "organizations_select_member" ON organizations;
DROP POLICY IF EXISTS "organizations_insert" ON organizations;
DROP POLICY IF EXISTS "user_organizations_select" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_insert" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;

-- Organizations policies
CREATE POLICY "allow_select_organizations" ON organizations
    FOR SELECT TO authenticated
    USING (
        is_default = true 
        OR id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "allow_insert_organizations" ON organizations
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- User organizations policies
CREATE POLICY "allow_select_user_organizations" ON user_organizations
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR organization_id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid()
            AND role_name IN ('Admin', 'Super-admin')
        )
    );

CREATE POLICY "allow_insert_user_organizations" ON user_organizations
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

-- User details policies
CREATE POLICY "allow_select_user_details" ON user_details
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "allow_insert_user_details" ON user_details
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "allow_update_user_details" ON user_details
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());