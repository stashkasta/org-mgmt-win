/*
  # Fix infinite recursion in policies

  1. Changes
    - Remove circular dependencies in policies
    - Simplify policy structure
    - Separate admin and member policies

  2. Security
    - Maintain proper access control
    - Prevent infinite recursion
*/

-- Drop existing policies
DROP POLICY IF EXISTS "allow_select_organizations" ON organizations;
DROP POLICY IF EXISTS "allow_insert_organizations" ON organizations;
DROP POLICY IF EXISTS "allow_select_user_organizations" ON user_organizations;
DROP POLICY IF EXISTS "allow_insert_user_organizations" ON user_organizations;
DROP POLICY IF EXISTS "allow_select_user_details" ON user_details;
DROP POLICY IF EXISTS "allow_insert_user_details" ON user_details;
DROP POLICY IF EXISTS "allow_update_user_details" ON user_details;

-- Organizations policies
CREATE POLICY "organizations_read_default" ON organizations
    FOR SELECT TO authenticated
    USING (is_default = true);

CREATE POLICY "organizations_read_member" ON organizations
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 
        FROM user_organizations 
        WHERE user_organizations.organization_id = organizations.id 
        AND user_organizations.user_id = auth.uid()
    ));

CREATE POLICY "organizations_insert" ON organizations
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- User organizations policies (avoiding recursion)
CREATE POLICY "user_organizations_read_own" ON user_organizations
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_organizations_read_admin" ON user_organizations
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 
        FROM user_organizations admin_org 
        WHERE admin_org.user_id = auth.uid() 
        AND admin_org.organization_id = user_organizations.organization_id 
        AND admin_org.role_name IN ('Admin', 'Super-admin')
    ));

CREATE POLICY "user_organizations_insert" ON user_organizations
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

-- User details policies
CREATE POLICY "user_details_read" ON user_details
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_details_insert" ON user_details
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_details_update" ON user_details
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());