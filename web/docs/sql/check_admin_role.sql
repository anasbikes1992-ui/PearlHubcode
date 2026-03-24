SELECT u.email, r.role FROM auth.users u
LEFT JOIN public.user_roles r ON u.id = r.user_id
WHERE u.email = 'admin@pearlhub.lk';