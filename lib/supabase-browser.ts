"use client";

import { createBrowserClient } from "@supabase/ssr";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";

export const authConfigured = Boolean(
  url && publishableKey && !publishableKey.includes("PASTE")
);

/** Browser Supabase client. Only call when `authConfigured` is true. */
export function getSupabaseBrowser() {
  return createBrowserClient(url, publishableKey);
}
