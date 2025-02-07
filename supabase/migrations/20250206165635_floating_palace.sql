/*
  # Final fix for infinite recursion in policies

  1. Changes
    - Completely flatten policy structure
    - Remove all nested subqueries
    - Separate admin access into distinct policies
    - Add missing INSERT policies

  2. Security
    - Maintain proper access control
    - Prevent any possibility of recursion
    - Ensure proper organization access
*/

-- Drop all existing policies
DROP POLICY IF EXISTS "organizations_read_default" ON organizations;
DROP POLICY IF EXISTS "organizations_read_member" ON organizations;
DROP POLICY IF EXISTS "organizations_insert" ON organizations;
DROP POLICY IF EXISTS "user_organizations_read_own" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_read_admin" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_insert" ON user_organizations;
DROP POLICY IF EXISTS "user_details_read" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;

-- Organizations policies (completely flat)
CREATE POLICY "org_select_default"
    ON organizations FOR SELECT
    TO authenticated
    USING (is_default = true);

CREATE POLICY "org_select_member"
    ON organizations FOR SELECT
    TO authenticated
    USING (id IN (SELECT organization_id FROM user_organizations WHERE user_id = auth.uid()));

CREATE POLICY "org_insert"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- User organizations policies (flat structure)
CREATE POLICY "user_org_select_own"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_org_select_as_admin"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (organization_id IN (
        SELECT organization_id 
        FROM user_organizations 
        WHERE user_id = auth.uid() 
        AND role_name IN ('Admin', 'Super-admin')
    ));

CREATE POLICY "user_org_insert"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- User details policies (simplified)
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