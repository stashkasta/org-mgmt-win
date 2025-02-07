/*
  # Update policies for organization management

  1. Changes
    - Simplify organization policies to allow creation and reading
    - Update user organization policies to allow proper admin creation
    - Ensure proper role assignment for new organizations
    - Fix policy conflicts for organization creation

  2. Security
    - Maintain RLS for organizations
    - Ensure proper access control for organization management
    - Prevent modification of default organization
*/

-- Drop existing organization policies
DROP POLICY IF EXISTS "allow_read_organizations" ON organizations;
DROP POLICY IF EXISTS "allow_insert_organizations" ON organizations;

-- Create new organization policies
CREATE POLICY "organizations_select"
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

CREATE POLICY "organizations_insert"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);

-- Update user organizations policies
DROP POLICY IF EXISTS "user_organizations_read" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_insert" ON user_organizations;

CREATE POLICY "user_organizations_select"
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

CREATE POLICY "user_organizations_insert"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        OR (
            -- Allow creating admin memberships during organization creation
            EXISTS (
                SELECT 1
                FROM organizations o
                WHERE o.id = organization_id
                AND NOT EXISTS (
                    SELECT 1 
                    FROM user_organizations uo 
                    WHERE uo.organization_id = organization_id
                )
            )
        )
    );

-- Update user details policies to ensure proper access
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;

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