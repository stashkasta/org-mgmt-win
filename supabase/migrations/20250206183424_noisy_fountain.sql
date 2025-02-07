-- Create default organization if it doesn't exist
DO $$
DECLARE
    starter_plan_id uuid;
BEGIN
    -- Get the Starter plan ID
    SELECT id INTO starter_plan_id
    FROM subscription_plans 
    WHERE name = 'Starter';

    -- Create default organization if it doesn't exist
    INSERT INTO organizations (
        name,
        registration_number,
        tax_number,
        subscription_plan_id,
        is_default
    )
    SELECT 
        'Default Organization',
        'DEFAULT001',
        'TAX001',
        starter_plan_id,
        true
    WHERE NOT EXISTS (
        SELECT 1 FROM organizations WHERE is_default = true
    );
END $$;