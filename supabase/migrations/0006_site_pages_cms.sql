-- ─────────────────────────────────────────────
-- 0006 · Site Pages CMS
-- Admin-managed static page content
-- ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.site_pages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,          -- e.g. 'home', 'about', 'contact', 'terms', 'privacy', 'faq'
  title       TEXT NOT NULL,
  hero_image  TEXT,                          -- URL to hero/banner image
  content     TEXT NOT NULL DEFAULT '',      -- Markdown or rich text body
  meta_desc   TEXT,                          -- SEO description
  is_published BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.touch_site_pages()
  RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS site_pages_updated ON public.site_pages;
CREATE TRIGGER site_pages_updated
  BEFORE UPDATE ON public.site_pages
  FOR EACH ROW EXECUTE FUNCTION public.touch_site_pages();

-- RLS
ALTER TABLE public.site_pages ENABLE ROW LEVEL SECURITY;

-- Public can read published pages
CREATE POLICY "site_pages_public_read"
  ON public.site_pages FOR SELECT
  USING (is_published = true);

-- Only admins can manage pages
CREATE POLICY "site_pages_admin_all"
  ON public.site_pages FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Seed default pages
INSERT INTO public.site_pages (slug, title, hero_image, content, meta_desc, is_published)
VALUES
  ('home',    'Home',          NULL, '# Welcome to Pearl Hub\n\nSri Lanka''s premier marketplace for stays, vehicles, events & more.', 'Pearl Hub – Sri Lanka''s #1 marketplace', true),
  ('about',   'About Us',      NULL, '# About Pearl Hub\n\nWe connect travellers with trusted local providers across Sri Lanka.', 'Learn about Pearl Hub''s mission.', true),
  ('contact', 'Contact Us',    NULL, '# Get in Touch\n\nEmail: support@pearlhub.lk\nWhatsApp: +94 77 000 0000', 'Contact Pearl Hub support team.', true),
  ('terms',   'Terms of Service', NULL, '# Terms of Service\n\nLast updated: 2025.\n\n...', 'Pearl Hub Terms of Service.', true),
  ('privacy', 'Privacy Policy', NULL, '# Privacy Policy\n\nYour privacy matters...', 'Pearl Hub Privacy Policy.', true),
  ('faq',     'FAQ',           NULL, '# Frequently Asked Questions\n\n**Q: How do I book?**\nA: Browse listings and click Book Now.', 'Pearl Hub FAQ.', true)
ON CONFLICT (slug) DO NOTHING;
