-- Add policies for member management
CREATE POLICY "user_organizations_delete_admin"
    ON user_organizations FOR DELETE
    TO authenticated
    USING (
        -- Allow super-admins to remove members
        EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE user_organizations.user_id = auth.uid() 
            AND user_organizations.role_name = 'Super-admin'
        )
        -- Prevent removing super-admin memberships
        AND NOT EXISTS (
            SELECT 1 
            FROM user_organizations target
            WHERE target.id = user_organizations.id 
            AND target.role_name = 'Super-admin'
        )
    );

-- Add policy for adding new members
CREATE POLICY "user_organizations_insert_admin"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (
        -- Allow super-admins to add members
        EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE user_organizations.user_id = auth.uid() 
            AND user_organizations.role_name = 'Super-admin'
        )
    );