-- Ensure default organization exists
DO $$
DECLARE
    starter_plan_id uuid;
    default_org_id uuid;
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
    )
    RETURNING id INTO default_org_id;

    -- If we created a new default organization, ensure it's the only default
    IF default_org_id IS NOT NULL THEN
        UPDATE organizations 
        SET is_default = false 
        WHERE id != default_org_id;
    END IF;
END $$;

-- Ensure all policies allow access to default organization
DROP POLICY IF EXISTS "allow_public_read_organizations" ON organizations;
DROP POLICY IF EXISTS "allow_auth_read_organizations" ON organizations;

CREATE POLICY "allow_read_organizations"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        is_default = true 
        OR id IN (
            SELECT organization_id 
            FROM user_organizations 
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "allow_insert_organizations"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (NOT is_default);