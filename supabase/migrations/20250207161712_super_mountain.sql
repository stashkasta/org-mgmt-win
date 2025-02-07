-- Drop existing view
DROP VIEW IF EXISTS users_view;

-- Recreate the view with proper permissions and search functionality
CREATE VIEW users_view WITH (security_barrier = true) AS
SELECT DISTINCT ON (u.id)
    u.id,
    u.email,
    u.email_confirmed_at,
    u.last_sign_in_at,
    COALESCE(ud.full_name, split_part(u.email, '@', 1)) as sort_name
FROM auth.users u
LEFT JOIN user_details ud ON u.id = ud.user_id
WHERE 
    -- Super admins can see all users
    EXISTS (
        SELECT 1 
        FROM user_organizations 
        WHERE user_organizations.user_id = auth.uid() 
        AND user_organizations.role_name = 'Super-admin'
    )
    -- Users can see their own data
    OR u.id = auth.uid();

-- Grant necessary permissions
GRANT SELECT ON users_view TO authenticated;