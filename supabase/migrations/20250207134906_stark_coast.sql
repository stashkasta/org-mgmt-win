/*
  # Fix foreign key constraints and policies

  1. Changes
    - Drop existing policies
    - Add proper foreign key constraints
    - Recreate policies with proper relationships
    - Add indexes for performance

  2. Foreign Keys
    - user_id references auth.users(id)
    - organization_id references organizations(id)
    - role_id references roles(id)
*/

-- First, drop all existing policies
DROP POLICY IF EXISTS "user_org_select_own" ON user_organizations;
DROP POLICY IF EXISTS "user_org_select_admin" ON user_organizations;
DROP POLICY IF EXISTS "user_org_insert" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_select" ON user_organizations;
DROP POLICY IF EXISTS "user_organizations_insert" ON user_organizations;

-- Add foreign key constraints with proper cascade behavior
ALTER TABLE user_organizations
  DROP CONSTRAINT IF EXISTS user_organizations_user_id_fkey,
  DROP CONSTRAINT IF EXISTS user_organizations_organization_id_fkey,
  DROP CONSTRAINT IF EXISTS user_organizations_role_id_fkey;

ALTER TABLE user_organizations
  ADD CONSTRAINT user_organizations_user_id_fkey 
    FOREIGN KEY (user_id) 
    REFERENCES auth.users(id) 
    ON DELETE CASCADE,
  ADD CONSTRAINT user_organizations_organization_id_fkey 
    FOREIGN KEY (organization_id) 
    REFERENCES organizations(id) 
    ON DELETE CASCADE,
  ADD CONSTRAINT user_organizations_role_id_fkey 
    FOREIGN KEY (role_id) 
    REFERENCES roles(id) 
    ON DELETE RESTRICT;

-- Add indexes to improve join performance
CREATE INDEX IF NOT EXISTS idx_user_organizations_user_id ON user_organizations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_organization_id ON user_organizations(organization_id);
CREATE INDEX IF NOT EXISTS idx_user_organizations_role_id ON user_organizations(role_id);

-- Add trigger to ensure role_name matches role_id
CREATE OR REPLACE FUNCTION sync_role_name()
RETURNS TRIGGER AS $$
BEGIN
  SELECT name INTO NEW.role_name
  FROM roles
  WHERE id = NEW.role_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS ensure_role_name_matches ON user_organizations;
CREATE TRIGGER ensure_role_name_matches
  BEFORE INSERT OR UPDATE ON user_organizations
  FOR EACH ROW
  EXECUTE FUNCTION sync_role_name();

-- Recreate policies
CREATE POLICY "user_org_select_own"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "user_org_select_admin"
  ON user_organizations FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 
      FROM user_organizations admin_org 
      WHERE admin_org.user_id = auth.uid()
      AND admin_org.organization_id = user_organizations.organization_id
      AND admin_org.role_name IN ('Admin', 'Super-admin')
    )
  );

CREATE POLICY "user_org_insert"
  ON user_organizations FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 
      FROM roles 
      WHERE id = role_id
    )
    AND EXISTS (
      SELECT 1 
      FROM organizations 
      WHERE id = organization_id
    )
  );