/*
  # Add Stashka user as Super-admin

  1. Changes
    - Create new user Stashka
    - Add user details
    - Add organization membership with Super-admin role
*/

DO $$
DECLARE
    new_user_id uuid;
    default_org_id uuid;
    super_admin_role_id uuid;
BEGIN
    -- Get the default organization ID
    SELECT id INTO default_org_id
    FROM organizations 
    WHERE is_default = true;

    -- Get the Super-admin role ID
    SELECT id INTO super_admin_role_id
    FROM roles 
    WHERE name = 'Super-admin';

    -- Create new user
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        recovery_sent_at,
        last_sign_in_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        'stashkasta@gmail.com',
        crypt('Tafsb&888', gen_salt('bf')),
        now(),
        now(),
        now(),
        '{"provider":"email","providers":["email"]}',
        '{}',
        now(),
        now(),
        '',
        '',
        '',
        ''
    ) RETURNING id INTO new_user_id;

    -- Create user details
    INSERT INTO user_details (user_id, full_name, active_organization_id)
    VALUES (new_user_id, 'Stashka', default_org_id);

    -- Add organization membership
    INSERT INTO user_organizations (user_id, organization_id, role_id, role_name)
    VALUES (new_user_id, default_org_id, super_admin_role_id, 'Super-admin');
END $$;