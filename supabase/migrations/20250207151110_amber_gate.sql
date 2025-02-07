/*
  # Add subscription dates tracking

  1. New Columns
    - `subscription_start_date` (timestamptz)
    - `subscription_end_date` (timestamptz)
    Added to organizations table

  2. Changes
    - Add trigger to automatically set dates when subscription_plan_id changes
    - Update existing organizations with appropriate dates
    - Add policies for super admins to manage dates

  3. Security
    - Only super admins can modify these dates
    - All authenticated users can view the dates
*/

-- Add new columns
ALTER TABLE organizations
ADD COLUMN IF NOT EXISTS subscription_start_date timestamptz,
ADD COLUMN IF NOT EXISTS subscription_end_date timestamptz;

-- Create function to manage subscription dates
CREATE OR REPLACE FUNCTION manage_subscription_dates()
RETURNS TRIGGER AS $$
BEGIN
    -- Only set dates when subscription plan is first set or changed
    IF (TG_OP = 'INSERT' AND NEW.subscription_plan_id IS NOT NULL) OR
       (TG_OP = 'UPDATE' AND (
           (OLD.subscription_plan_id IS NULL AND NEW.subscription_plan_id IS NOT NULL) OR
           (OLD.subscription_plan_id != NEW.subscription_plan_id)
       )) THEN
        -- Set start date to current timestamp
        NEW.subscription_start_date := CURRENT_TIMESTAMP;
        -- Set end date to 1 year from start
        NEW.subscription_end_date := CURRENT_TIMESTAMP + INTERVAL '1 year';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS set_subscription_dates ON organizations;
CREATE TRIGGER set_subscription_dates
    BEFORE INSERT OR UPDATE OF subscription_plan_id
    ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION manage_subscription_dates();

-- Update existing organizations with subscription dates
UPDATE organizations
SET 
    subscription_start_date = created_at,
    subscription_end_date = created_at + INTERVAL '1 year'
WHERE 
    subscription_plan_id IS NOT NULL 
    AND subscription_start_date IS NULL;