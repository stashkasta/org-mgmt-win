/*
  # Create secure users view for super admins

  1. Changes
    - Create a secure view of necessary auth.users data
    - Grant appropriate permissions to authenticated users
    - Add security barrier to prevent information leakage
  
  2. Security
    - Only super admins can access the view
    - Uses security barrier to prevent leaking data
    - Filters data through RLS policies
*/

-- Create a secure view to expose necessary auth.users data
CREATE OR REPLACE VIEW users_view WITH (security_barrier = true) AS
SELECT 
    u.id,
    u.email,
    u.email_confirmed_at,
    u.last_sign_in_at
FROM auth.users u
WHERE EXISTS (
    SELECT 1 
    FROM super_admin_users 
    WHERE user_id = auth.uid()
);

-- Grant access to authenticated users
GRANT SELECT ON users_view TO authenticated;