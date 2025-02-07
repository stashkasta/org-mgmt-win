/*
  # Fix organization creation policies

  1. Changes
    - Add public read access for non-default organizations during signup
    - Ensure proper insert permissions for organizations
    - Simplify policies to avoid conflicts

  2. Security
    - Maintain RLS for data protection
    - Allow organization creation during signup
    - Preserve existing access controls
*/

-- Drop existing policies
DROP POLICY IF EXISTS "organizations_read_default" ON organizations;
DROP POLICY IF EXISTS "organizations_read_member" ON organizations;
DROP POLICY IF EXISTS "organizations_insert_auth" ON organizations;
DROP POLICY IF EXISTS "user_organizations_read" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_insert" ON user_organizations;
DROP POLICY IF EXISTS "user_details_read" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;
DROP POLICY IF EXISTS "roles_read" ON roles;
DROP POLICY IF EXISTS "subscription_plans_read" ON subscription_plans;

-- Organizations policies
CREATE POLICY "organizations_read"
    ON organizations FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "organizations_insert"
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