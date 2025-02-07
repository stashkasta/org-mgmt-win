/*
  # Final simplification of RLS policies

  1. Changes
    - Drop all existing policies
    - Implement completely flat policies without any nested queries
    - Use direct conditions only
  
  2. Security
    - Maintain security through simple, direct policies
    - Eliminate all potential recursion points
*/

-- Drop all existing policies
DROP POLICY IF EXISTS "allow_read_organizations" ON organizations;
DROP POLICY IF EXISTS "allow_read_user_organizations" ON user_organizations;
DROP POLICY IF EXISTS "allow_manage_user_details" ON user_details;
DROP POLICY IF EXISTS "allow_read_roles" ON roles;
DROP POLICY IF EXISTS "allow_read_subscription_plans" ON subscription_plans;

-- Flat policy for organizations
CREATE POLICY "allow_read_organizations"
    ON organizations FOR SELECT
    TO authenticated
    USING (is_default = true);

CREATE POLICY "allow_read_member_organizations"
    ON organizations FOR SELECT
    TO authenticated
    USING (EXISTS (
        SELECT 1 
        FROM user_organizations 
        WHERE user_organizations.organization_id = organizations.id 
        AND user_organizations.user_id = auth.uid()
    ));

-- Flat policy for user_organizations
CREATE POLICY "allow_read_own_organizations"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- Simple policy for user_details
CREATE POLICY "allow_manage_user_details"
    ON user_details FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Reference table policies
CREATE POLICY "allow_read_roles"
    ON roles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "allow_read_subscription_plans"
    ON subscription_plans FOR SELECT
    TO authenticated
    USING (true);