/*
  # Remove non-default organizations

  1. Changes
    - Delete all user organization memberships for non-default organizations
    - Delete all non-default organizations
    - Update user details to point to default organization

  2. Security
    - Maintains RLS policies
    - Preserves default organization
*/

-- First, get the default organization ID
WITH default_org AS (
  SELECT id FROM organizations WHERE is_default = true
)
UPDATE user_details
SET active_organization_id = (SELECT id FROM default_org)
WHERE active_organization_id IN (
  SELECT id FROM organizations WHERE is_default = false
);

-- Delete user organization memberships for non-default organizations
DELETE FROM user_organizations
WHERE organization_id IN (
  SELECT id FROM organizations WHERE is_default = false
);

-- Delete non-default organizations
DELETE FROM organizations
WHERE is_default = false;