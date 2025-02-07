/*
  # Fix organization creation policies

  1. Changes
    - Simplify organization policies to allow creation
    - Add explicit policies for all required operations
    - Ensure proper access control while allowing new organization creation

  2. Security
    - Maintain RLS for data protection
    - Allow authenticated users to create organizations
    - Preserve read access controls
*/

-- Drop existing policies
DROP POLICY IF EXISTS "org_select_default" ON organizations;
DROP POLICY IF EXISTS "org_select_member" ON organizations;
DROP POLICY IF EXISTS "org_insert" ON organizations;
DROP POLICY IF EXISTS "user_org_select_own" ON user_organizations;
DROP POLICY IF EXISTS "user_org_insert" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;
DROP POLICY IF EXISTS "roles_select" ON roles;
DROP POLICY IF EXISTS "subscription_plans_select" ON subscription_plans;

-- Organizations policies
CREATE POLICY "organizations_read_default"
    ON organizations FOR SELECT
    TO authenticated
    USING (is_default = true);

CREATE POLICY "organizations_read_member"
    ON organizations FOR SELECT
    TO authenticated
    USING (EXISTS (
        SELECT 1 
        FROM user_organizations 
        WHERE user_organizations.organization_id = organizations.id 
        AND user_organizations.user_id = auth.uid()
    ));

CREATE POLICY "organizations_insert_auth"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);

-- User organizations policies
CREATE POLICY "user_organizations_read"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_organizations_insert"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- User details policies
CREATE POLICY "user_details_read"
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

-- Reference table policies
CREATE POLICY "roles_read"
    ON roles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "subscription_plans_read"
    ON subscription_plans FOR SELECT
    TO authenticated
    USING (true);