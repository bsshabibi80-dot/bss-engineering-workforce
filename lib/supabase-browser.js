import { createBrowserClient } from '@supabase/ssr';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabase = url && key ? createBrowserClient(url, key) : null;
export function supabaseBrowser(){ return supabase; }
export const supabaseConfigured = Boolean(url && key);
