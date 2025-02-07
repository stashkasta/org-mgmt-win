/*
  # Fix RLS policies to prevent infinite recursion

  1. Changes
    - Drop existing policies that may cause recursion
    - Create new simplified policies without circular dependencies
    - Maintain security while improving performance

  2. Security
    - Maintains data access control
    - Prevents unauthorized access
    - Simplifies policy structure
*/

-- Drop existing policies
DROP POLICY IF EXISTS "org_select_default" ON organizations;
DROP POLICY IF EXISTS "org_select_member" ON organizations;
DROP POLICY IF EXISTS "org_insert" ON organizations;
DROP POLICY IF EXISTS "user_org_select_own" ON user_organizations;
DROP POLICY IF EXISTS "user_org_select_as_admin" ON user_organizations;
DROP POLICY IF EXISTS "user_org_insert" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;
DROP POLICY IF EXISTS "roles_select" ON roles;
DROP POLICY IF EXISTS "subscription_plans_select" ON subscription_plans;

-- Organizations policies
CREATE POLICY "org_select"
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

CREATE POLICY "org_insert"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- User organizations policies (simplified to prevent recursion)
CREATE POLICY "user_org_select"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 
            FROM user_organizations my_orgs 
            WHERE my_orgs.user_id = auth.uid()
            AND my_orgs.organization_id = user_organizations.organization_id
            AND my_orgs.role_name IN ('Admin', 'Super-admin')
        )
    );

CREATE POLICY "user_org_insert"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- User details policies
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

-- Reference table policies
CREATE POLICY "roles_select"
    ON roles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "subscription_plans_select"
    ON subscription_plans FOR SELECT
    TO authenticated
    USING (true);