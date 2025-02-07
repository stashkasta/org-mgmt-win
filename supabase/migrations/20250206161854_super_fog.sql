/*
  # Organization Management Schema

  1. New Tables
    - All tables from previous migration
    - Modified constraint handling for default organization

  2. Security
    - Same RLS policies as before

  3. Initial Data
    - Same initial data as before
*/

-- Create subscription_plans table
CREATE TABLE subscription_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    price integer NOT NULL,
    currency text NOT NULL,
    max_users integer NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create organizations table
CREATE TABLE organizations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    email text,
    address text,
    phone text,
    registration_number text NOT NULL UNIQUE,
    tax_number text NOT NULL UNIQUE,
    subscription_plan_id uuid REFERENCES subscription_plans(id),
    is_default boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create roles table
CREATE TABLE roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create user_details table
CREATE TABLE user_details (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users NOT NULL,
    full_name text,
    active_organization_id uuid REFERENCES organizations(id),
    last_active_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(user_id)
);

-- Create user_organizations table
CREATE TABLE user_organizations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users NOT NULL,
    organization_id uuid REFERENCES organizations(id) NOT NULL,
    role_id uuid REFERENCES roles(id) NOT NULL,
    role_name text NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(user_id, organization_id)
);

-- Function to enforce single default organization
CREATE OR REPLACE FUNCTION check_single_default_organization()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_default THEN
        UPDATE organizations SET is_default = false WHERE id != NEW.id;
        RETURN NEW;
    END IF;
    
    -- Ensure at least one default organization exists
    IF NOT EXISTS (SELECT 1 FROM organizations WHERE is_default = true AND id != NEW.id) THEN
        RAISE EXCEPTION 'At least one organization must be marked as default';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for single default organization
CREATE TRIGGER ensure_single_default_organization
    BEFORE INSERT OR UPDATE OF is_default
    ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION check_single_default_organization();

-- Enable Row Level Security
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_organizations ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
CREATE POLICY "Authenticated users can read subscription plans"
    ON subscription_plans FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can read organizations they belong to"
    ON organizations FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_organizations
            WHERE user_organizations.organization_id = organizations.id
            AND user_organizations.user_id = auth.uid()
        )
        OR is_default = true
    );

CREATE POLICY "Authenticated users can read roles"
    ON roles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can read their own details"
    ON user_details FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can read organization memberships"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR organization_id IN (
            SELECT organization_id FROM user_organizations
            WHERE user_id = auth.uid()
            AND role_name IN ('Admin', 'Super-admin')
        )
    );

-- Insert initial data
INSERT INTO subscription_plans (name, price, currency, max_users) VALUES
    ('Pro', 2499, 'EUR', 20),
    ('Starter', 1499, 'EUR', 10),
    ('Premium', 4999, 'EUR', 100);

INSERT INTO roles (name) VALUES
    ('Super-admin'),
    ('Admin'),
    ('Member');

-- Insert default organization
WITH starter_plan AS (
    SELECT id FROM subscription_plans WHERE name = 'Starter'
)
INSERT INTO organizations (
    name,
    registration_number,
    tax_number,
    subscription_plan_id,
    is_default
) VALUES (
    'Default Organization',
    '0000000',
    'TAX0000000',
    (SELECT id FROM starter_plan),
    true
);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_subscription_plans_updated_at
    BEFORE UPDATE ON subscription_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_details_updated_at
    BEFORE UPDATE ON user_details
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_organizations_updated_at
    BEFORE UPDATE ON user_organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();