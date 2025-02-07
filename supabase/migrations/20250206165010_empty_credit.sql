/*
  # Add INSERT policy for organizations

  1. Changes
    - Add policy to allow authenticated users to create organizations
  
  2. Security
    - Only authenticated users can create organizations
    - Maintains existing read policies
*/

-- Add INSERT policy for organizations
CREATE POLICY "allow_create_organizations"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Add INSERT policy for user_organizations to allow initial admin creation
CREATE POLICY "allow_create_user_organizations"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Add INSERT policy for user_details
CREATE POLICY "allow_create_user_details"
    ON user_details FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());