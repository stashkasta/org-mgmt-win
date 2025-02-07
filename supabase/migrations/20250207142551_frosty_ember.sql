/*
  # Update users view with alphabetical sorting

  1. Changes
    - Modify users_view to include user_details
    - Add COALESCE to handle null full names
    - Add ORDER BY clause for alphabetical sorting

  2. Security
    - Maintain existing security barrier
    - Keep super admin access restriction
*/

-- Drop existing view
DROP VIEW IF EXISTS users_view;

-- Create updated view with sorting
CREATE OR REPLACE VIEW users_view WITH (security_barrier = true) AS
SELECT 
    u.id,
    u.email,
    u.email_confirmed_at,
    u.last_sign_in_at,
    COALESCE(ud.full_name, split_part(u.email, '@', 1)) as sort_name
FROM auth.users u
LEFT JOIN user_details ud ON u.id = ud.user_id
WHERE EXISTS (
    SELECT 1 
    FROM super_admin_users 
    WHERE user_id = auth.uid()
)
ORDER BY 
    COALESCE(ud.full_name, split_part(u.email, '@', 1)) COLLATE "C" ASC;

-- Grant access to authenticated users
GRANT SELECT ON users_view TO authenticated;