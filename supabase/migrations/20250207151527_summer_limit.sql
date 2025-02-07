/*
  # Enable subscription date editing for super admins

  1. Changes
    - Allow super admins to directly edit subscription dates
    - Remove automatic date setting trigger for manual control
    - Update policies to allow date modifications

  2. Security
    - Only super admins can modify subscription dates
    - Dates can be modified independently of subscription plan changes
*/

-- Drop existing trigger to allow manual date control
DROP TRIGGER IF EXISTS set_subscription_dates ON organizations;
DROP FUNCTION IF EXISTS manage_subscription_dates();

-- Update the organizations update policy to explicitly allow subscription date changes
DROP POLICY IF EXISTS "organizations_update" ON organizations;

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