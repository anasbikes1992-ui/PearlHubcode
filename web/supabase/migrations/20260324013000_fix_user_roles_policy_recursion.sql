-- Fix infinite recursion in user_roles RLS policy.
-- Root cause: policy self-queries user_roles table in its own USING clause.

DROP POLICY IF EXISTS "Admins can read all roles" ON public.user_roles;

CREATE POLICY "Admins can read all roles"
  ON public.user_roles FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));
