/*
  # Fix RLS policies to eliminate circular dependencies

  1. Changes
    - Drop all existing policies
    - Restructure policies to avoid circular references
    - Simplify policy logic
  
  2. Security
    - Maintain security while avoiding recursion
    - Keep all necessary access controls
*/

-- Drop all existing policies
DROP POLICY IF EXISTS "Authenticated users can read organizations they belong to" ON organizations;
DROP POLICY IF EXISTS "Users can read organization memberships" ON user_organizations;
DROP POLICY IF EXISTS "Users can read their own details" ON user_details;
DROP POLICY IF EXISTS "Authenticated users can read roles" ON roles;
DROP POLICY IF EXISTS "Authenticated users can read subscription plans" ON subscription_plans;
DROP POLICY IF EXISTS "Public can read default organization" ON organizations;
DROP POLICY IF EXISTS "Members can read their organizations" ON organizations;
DROP POLICY IF EXISTS "Users can read their own memberships" ON user_organizations;
DROP POLICY IF EXISTS "Organization admins can read member details" ON user_organizations;
DROP POLICY IF EXISTS "Users can update their own details" ON user_details;
DROP POLICY IF EXISTS "organizations_read_default" ON organizations;
DROP POLICY IF EXISTS "organizations_read_member" ON organizations;
DROP POLICY IF EXISTS "user_organizations_read_own" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_read_admin" ON user_organizations;
DROP POLICY IF EXISTS "user_details_read" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;
DROP POLICY IF EXISTS "roles_read" ON roles;
DROP POLICY IF EXISTS "subscription_plans_read" ON subscription_plans;

-- Create simplified policies for organizations
CREATE POLICY "allow_read_default_org"
    ON organizations FOR SELECT
    TO authenticated
    USING (is_default = true);

CREATE POLICY "allow_read_member_org"
    ON organizations FOR SELECT
    TO authenticated
    USING (EXISTS (
        SELECT 1 
        FROM user_organizations 
        WHERE user_organizations.organization_id = organizations.id 
        AND user_organizations.user_id = auth.uid()
    ));

-- Create simplified policies for user_organizations
CREATE POLICY "allow_read_own_membership"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "allow_admin_read_org_members"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (
        organization_id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid() 
            AND role_name IN ('Admin', 'Super-admin')
        )
    );

-- Create policies for user_details
CREATE POLICY "allow_read_own_details"
    ON user_details FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "allow_update_own_details"
    ON user_details FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Create policies for roles and subscription_plans
CREATE POLICY "allow_read_roles"
    ON roles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "allow_read_subscription_plans"
    ON subscription_plans FOR SELECT
    TO authenticated
    USING (true);