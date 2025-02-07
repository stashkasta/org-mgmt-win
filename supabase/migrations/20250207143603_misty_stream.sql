/*
  # Fix recursive policies

  1. Changes
    - Drop existing policies that cause recursion
    - Create new non-recursive policies using subqueries
    - Simplify policy conditions to avoid circular dependencies
*/

-- Drop existing policies
DROP POLICY IF EXISTS "user_organizations_select" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;

-- Drop existing view
DROP VIEW IF EXISTS users_view;

-- Create users view with non-recursive role check
CREATE OR REPLACE VIEW users_view WITH (security_barrier = true) AS
WITH super_admins AS (
  SELECT DISTINCT user_id
  FROM user_organizations
  WHERE role_name = 'Super-admin'
)
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
    FROM super_admins 
    WHERE user_id = auth.uid()
)
ORDER BY 
    COALESCE(ud.full_name, split_part(u.email, '@', 1)) COLLATE "C" ASC;

-- Grant access to authenticated users
GRANT SELECT ON users_view TO authenticated;

-- Create non-recursive policies
CREATE POLICY "user_organizations_select"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    -- Users can always see their own memberships
    user_id = auth.uid()
    OR
    -- Super-admins can see all memberships (using non-recursive subquery)
    EXISTS (
      SELECT 1 
      FROM (
        SELECT DISTINCT uo.user_id
        FROM user_organizations uo
        WHERE uo.role_name = 'Super-admin'
      ) sa
      WHERE sa.user_id = auth.uid()
    )
  );

CREATE POLICY "user_details_select"
  ON user_details FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM (
        SELECT DISTINCT uo.user_id
        FROM user_organizations uo
        WHERE uo.role_name = 'Super-admin'
      ) sa
      WHERE sa.user_id = auth.uid()
    )
  );

CREATE POLICY "user_details_insert"
  ON user_details FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM (
        SELECT DISTINCT uo.user_id
        FROM user_organizations uo
        WHERE uo.role_name = 'Super-admin'
      ) sa
      WHERE sa.user_id = auth.uid()
    )
  );

CREATE POLICY "user_details_update"
  ON user_details FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM (
        SELECT DISTINCT uo.user_id
        FROM user_organizations uo
        WHERE uo.role_name = 'Super-admin'
      ) sa
      WHERE sa.user_id = auth.uid()
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM (
        SELECT DISTINCT uo.user_id
        FROM user_organizations uo
        WHERE uo.role_name = 'Super-admin'
      ) sa
      WHERE sa.user_id = auth.uid()
    )
  );