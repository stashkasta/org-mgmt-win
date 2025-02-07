-- Add expired column with a default value of false
ALTER TABLE organizations
ADD COLUMN IF NOT EXISTS is_expired boolean DEFAULT false;

-- Create function to calculate if subscription is expired
CREATE OR REPLACE FUNCTION calculate_subscription_expired()
RETURNS TRIGGER AS $$
BEGIN
    -- Set is_expired based on subscription_end_date
    NEW.is_expired := CASE
        WHEN NEW.subscription_end_date IS NULL THEN false
        WHEN NEW.subscription_end_date < CURRENT_TIMESTAMP THEN true
        ELSE false
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update is_expired
CREATE TRIGGER update_subscription_expired
    BEFORE INSERT OR UPDATE OF subscription_end_date
    ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION calculate_subscription_expired();

-- Update existing organizations
UPDATE organizations
SET is_expired = CASE
    WHEN subscription_end_date IS NULL THEN false
    WHEN subscription_end_date < CURRENT_TIMESTAMP THEN true
    ELSE false
END;