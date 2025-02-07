-- Add update policy for organizations
CREATE POLICY "organizations_update"
    ON organizations FOR UPDATE
    TO authenticated
    USING (
        -- Super-admins can update any organization except the default one
        EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE user_organizations.user_id = auth.uid() 
            AND user_organizations.role_name = 'Super-admin'
        )
        AND NOT is_default -- Prevent updating the default organization
    )
    WITH CHECK (
        -- Super-admins can update any organization except the default one
        EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE user_organizations.user_id = auth.uid() 
            AND user_organizations.role_name = 'Super-admin'
        )
        AND NOT is_default -- Prevent updating the default organization
    );