-- Create admin user (only if doesn't exist)
DO $$
DECLARE
  admin_user_id UUID;
BEGIN
  -- Check if user already exists
  SELECT id INTO admin_user_id FROM auth.users WHERE email = 'admin@pearlhub.lk';

  IF admin_user_id IS NULL THEN
    -- Create new user
    INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_user_meta_data)
    VALUES (
      gen_random_uuid(),
      'admin@pearlhub.lk',
      crypt('Aa123456', gen_salt('bf')),
      now(),
      now(),
      now(),
      '{"full_name": "Admin User", "role": "admin"}'::jsonb
    )
    RETURNING id INTO admin_user_id;
  END IF;

  -- Promote to admin role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (admin_user_id, 'admin'::public.app_role)
  ON CONFLICT (user_id, role) DO NOTHING;

  -- Update profile
  UPDATE public.profiles
  SET role = 'admin'::public.app_role, full_name = 'Admin User', email = 'admin@pearlhub.lk', updated_at = now()
  WHERE id = admin_user_id;
END $$;