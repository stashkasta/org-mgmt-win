/*
  # Add member count check for organizations

  Changes:
  - Add policy to allow counting members for organizations
  - Add policy to allow reading subscription plans for member limit checks
*/

-- Allow counting members for organizations
CREATE POLICY "allow_count_organization_members"
    ON user_organizations FOR SELECT
    USING (true);

-- Ensure subscription plans are readable
CREATE POLICY "allow_read_subscription_plans_for_limits"
    ON subscription_plans FOR SELECT
    USING (true);