-- Drop existing policy if it exists
DROP POLICY IF EXISTS "allow_super_admin_read_users" ON users_view;

-- Create policy to allow super-admins to view all users
CREATE POLICY "allow_super_admin_read_users"
    ON users_view FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 
            FROM user_organizations 
            WHERE user_organizations.user_id = auth.uid() 
            AND user_organizations.role_name = 'Super-admin'
        )
    );