import { NextResponse } from "next/server";
import { getSupabaseServer } from "@/lib/supabase";

export const runtime = "nodejs";

/** Magic-link landing: exchanges the one-time code for a session cookie. */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const next = url.searchParams.get("next") ?? "/dashboard";
  // Only allow same-site redirects — never bounce to an attacker-supplied host
  const safeNext = next.startsWith("/") && !next.startsWith("//") ? next : "/dashboard";

  if (!code) {
    return NextResponse.redirect(new URL("/login?error=missing-code", url.origin));
  }

  const supabase = await getSupabaseServer();
  if (!supabase) {
    return NextResponse.redirect(new URL("/login?error=not-configured", url.origin));
  }

  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    return NextResponse.redirect(new URL("/login?error=expired", url.origin));
  }

  return NextResponse.redirect(new URL(safeNext, url.origin));
}
