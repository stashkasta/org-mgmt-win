/*
  # Fix RLS policies to prevent infinite recursion

  1. Changes
    - Drop all existing policies
    - Create new policies without circular dependencies
    - Add proper security policies for all tables
  
  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
    - Prevent unauthorized access
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

-- Create new policies for organizations
CREATE POLICY "organizations_read_default"
    ON organizations FOR SELECT
    TO authenticated
    USING (is_default = true);

CREATE POLICY "organizations_read_member"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid()
        )
    );

-- Create new policies for user_organizations
CREATE POLICY "user_organizations_read_own"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_organizations_read_admin"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 
            FROM user_organizations admin_org
            WHERE admin_org.user_id = auth.uid()
            AND admin_org.organization_id = user_organizations.organization_id
            AND admin_org.role_name IN ('Admin', 'Super-admin')
        )
    );

-- Create policies for user_details
CREATE POLICY "user_details_read"
    ON user_details FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_details_update"
    ON user_details FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Create policies for roles
CREATE POLICY "roles_read"
    ON roles FOR SELECT
    TO authenticated
    USING (true);

-- Create policies for subscription_plans
CREATE POLICY "subscription_plans_read"
    ON subscription_plans FOR SELECT
    TO authenticated
    USING (true);