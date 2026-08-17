import { createBrowserClient } from '@supabase/ssr';

// Vercel env is preferred. Publishable keys are designed for browser use with RLS enabled.
const url = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://fzjgktgvmavuirfipfha.supabase.co';
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'sb_publishable_kZnIPkZm9W_MOKFSErv-7w_u937Fz4w';

export const supabase = createBrowserClient(url, key);
export function supabaseBrowser(){ return supabase; }
export const supabaseConfigured = Boolean(url && key);
