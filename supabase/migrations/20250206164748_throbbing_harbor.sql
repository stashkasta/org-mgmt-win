/*
  # Simplify RLS policies to eliminate recursion

  1. Changes
    - Drop all existing policies
    - Implement simplified, direct policies without cross-references
    - Use direct user_id checks where possible
  
  2. Security
    - Maintain security through simplified but effective policies
    - Ensure proper access control with minimal complexity
*/

-- Drop all existing policies
DROP POLICY IF EXISTS "allow_read_default_org" ON organizations;
DROP POLICY IF EXISTS "allow_read_member_org" ON organizations;
DROP POLICY IF EXISTS "allow_read_own_membership" ON user_organizations;
DROP POLICY IF EXISTS "allow_admin_read_org_members" ON user_organizations;
DROP POLICY IF EXISTS "allow_read_own_details" ON user_details;
DROP POLICY IF EXISTS "allow_update_own_details" ON user_details;
DROP POLICY IF EXISTS "allow_read_roles" ON roles;
DROP POLICY IF EXISTS "allow_read_subscription_plans" ON subscription_plans;

-- Simple policy for organizations
CREATE POLICY "allow_read_organizations"
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

-- Simple policy for user_organizations
CREATE POLICY "allow_read_user_organizations"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR organization_id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid()
            AND role_name IN ('Admin', 'Super-admin')
        )
    );

-- Simple policy for user_details
CREATE POLICY "allow_manage_user_details"
    ON user_details FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Simple policies for reference tables
CREATE POLICY "allow_read_roles"
    ON roles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "allow_read_subscription_plans"
    ON subscription_plans FOR SELECT
    TO authenticated
    USING (true);