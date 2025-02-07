-- Drop existing policies
DROP POLICY IF EXISTS "org_select" ON organizations;
DROP POLICY IF EXISTS "org_insert" ON organizations;
DROP POLICY IF EXISTS "user_org_select" ON user_organizations;
DROP POLICY IF EXISTS "user_org_insert" ON user_organizations;
DROP POLICY IF EXISTS "user_details_select" ON user_details;
DROP POLICY IF EXISTS "user_details_insert" ON user_details;
DROP POLICY IF EXISTS "user_details_update" ON user_details;
DROP POLICY IF EXISTS "roles_select" ON roles;
DROP POLICY IF EXISTS "subscription_plans_select" ON subscription_plans;

-- Organizations policies
CREATE POLICY "org_select_default"
    ON organizations FOR SELECT
    TO authenticated
    USING (is_default = true);

CREATE POLICY "org_select_member"
    ON organizations FOR SELECT
    TO authenticated
    USING (EXISTS (
        SELECT 1 
        FROM user_organizations 
        WHERE user_organizations.organization_id = organizations.id 
        AND user_organizations.user_id = auth.uid()
    ));

CREATE POLICY "org_insert"
    ON organizations FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- User organizations policies
CREATE POLICY "user_org_select_own"
    ON user_organizations FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_org_insert"
    ON user_organizations FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- User details policies
CREATE POLICY "user_details_select"
    ON user_details FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "user_details_insert"
    ON user_details FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_details_update"
    ON user_details FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Reference table policies
CREATE POLICY "roles_select"
    ON roles FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "subscription_plans_select"
    ON subscription_plans FOR SELECT
    TO authenticated
    USING (true);