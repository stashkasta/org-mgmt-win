-- Add blocking columns
ALTER TABLE organizations
ADD COLUMN IF NOT EXISTS is_blocked boolean DEFAULT false;

ALTER TABLE user_organizations
ADD COLUMN IF NOT EXISTS is_blocked boolean DEFAULT false;

-- Create function to cascade organization block to members
CREATE OR REPLACE FUNCTION cascade_organization_block()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_blocked = true THEN
        -- When organization is blocked, block all its members
        UPDATE user_organizations
        SET is_blocked = true
        WHERE organization_id = NEW.id;
    ELSIF NEW.is_blocked = false AND OLD.is_blocked = true THEN
        -- When organization is unblocked, unblock all its members
        UPDATE user_organizations
        SET is_blocked = false
        WHERE organization_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for cascading organization blocks
CREATE TRIGGER cascade_organization_block
    AFTER UPDATE OF is_blocked
    ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION cascade_organization_block();

-- Update RLS policies to prevent access when blocked
DROP POLICY IF EXISTS "org_public_read_20250209" ON organizations;
DROP POLICY IF EXISTS "org_member_read_20250209" ON organizations;

CREATE POLICY "org_public_read_20250209"
    ON organizations FOR SELECT
    USING (
        NOT is_default 
        AND NOT is_blocked
    );

CREATE POLICY "org_member_read_20250209"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        is_default = true 
        OR (
            id IN (
                SELECT organization_id 
                FROM user_organizations 
                WHERE user_id = auth.uid()
                AND NOT is_blocked
            )
            AND NOT is_blocked
        )
    );