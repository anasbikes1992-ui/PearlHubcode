import { createClient } from '@supabase/supabase-js';
import type { Database } from './types';

// These fallback values are the project's own Supabase credentials (publishable/anon keys are
// intentionally public and safe for client-side use).  They ensure the app loads on Vercel even
// when the VITE_* environment variables have not yet been configured in the project settings.
// To use a different Supabase project, set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY
// (or VITE_SUPABASE_ANON_KEY) in your Vercel environment variables — those values take precedence.
const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL ||
  'https://pxuydclxnnfgzpzccfoa.supabase.co';

const SUPABASE_PUBLISHABLE_KEY =
  import.meta.env.VITE_SUPABASE_ANON_KEY ||
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
  'sb_publishable_XJZSHY9N6n1JVg9JvRd31Q_cJ5kjqBk';

// Import the supabase client like this:
// import { supabase } from "@/integrations/supabase/client";

export const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    storage: localStorage,
    persistSession: true,
    autoRefreshToken: true,
  }
});