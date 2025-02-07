/*
  # Update user details policies for super admin access

  1. Changes
    - Drop existing user details policies
    - Add new policies that allow super admins to manage all user details
    - Keep existing policies for regular users to manage their own details

  2. Security
    - Super admins can manage all user details
    - Regular users can only manage their own details
    - All operations are protected by RLS
*/

-- Drop existing user details policies
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;
DROP POLICY IF EXISTS "allow_manage_user_details" ON user_details;
DROP POLICY IF EXISTS "allow_select_user_details" ON user_details;
DROP POLICY IF EXISTS "allow_insert_user_details" ON user_details;
DROP POLICY IF EXISTS "allow_update_user_details" ON user_details;

-- Create new policies that include super admin access
CREATE POLICY "user_details_select"
  ON user_details FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "user_details_insert"
  ON user_details FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "user_details_update"
  ON user_details FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 
      FROM super_admin_users 
      WHERE user_id = auth.uid()
    )
  );