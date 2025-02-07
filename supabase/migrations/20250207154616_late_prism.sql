-- Add update policy for user_organizations to allow super-admins to block members
CREATE POLICY "user_organizations_update_admin"
    ON user_organizations FOR UPDATE
    TO authenticated
    USING (
        -- Allow super-admins to update any member's status
        EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE user_organizations.user_id = auth.uid() 
            AND user_organizations.role_name = 'Super-admin'
        )
        -- Prevent updating super-admin memberships
        AND NOT EXISTS (
            SELECT 1 
            FROM user_organizations target
            WHERE target.id = user_organizations.id 
            AND target.role_name = 'Super-admin'
        )
    )
    WITH CHECK (
        -- Allow super-admins to update any member's status
        EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE user_organizations.user_id = auth.uid() 
            AND user_organizations.role_name = 'Super-admin'
        )
        -- Prevent updating super-admin memberships
        AND NOT EXISTS (
            SELECT 1 
            FROM user_organizations target
            WHERE target.id = user_organizations.id 
            AND target.role_name = 'Super-admin'
        )
    );