import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

/**
 * Server-side Supabase admin client (service role — bypasses RLS).
 * Returns null when env vars are not set, so the app runs in demo mode
 * (forms succeed but nothing is persisted).
 */
export function getSupabaseAdmin(): SupabaseClient | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) return null;
  return createClient(url, serviceKey, {
    auth: { persistSession: false },
  });
}

/** The publishable ("anon") key is safe to ship to the browser. */
export const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
export const SUPABASE_PUBLISHABLE_KEY =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";

/**
 * Auth needs the publishable key on top of the service-role key. Until it's
 * set, sign-in is disabled with a clear message rather than a crash — the
 * public marketing pages keep working either way.
 */
export function isAuthConfigured(): boolean {
  return Boolean(
    SUPABASE_URL &&
      SUPABASE_PUBLISHABLE_KEY &&
      !SUPABASE_PUBLISHABLE_KEY.includes("PASTE")
  );
}

/**
 * Session-aware client for Server Components and Route Handlers. Reads the
 * signed-in user from cookies and enforces RLS as that user.
 */
export async function getSupabaseServer() {
  if (!isAuthConfigured()) return null;
  const cookieStore = await cookies();
  return createServerClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: (list) => {
        try {
          for (const { name, value, options } of list) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Called from a Server Component — middleware refreshes the session instead.
        }
      },
    },
  });
}

/** The signed-in user, or null. Safe to call when auth isn't configured. */
export async function getCurrentUser() {
  const supabase = await getSupabaseServer();
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user;
}
