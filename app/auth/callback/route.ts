import { NextResponse } from "next/server";
import { getSupabaseServer } from "@/lib/supabase";
import { resolveNext } from "@/lib/safe-next";

export const runtime = "nodejs";

/** Magic-link landing: exchanges the one-time code for a session cookie. */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  // Only allow same-origin redirects — never bounce a freshly signed-in user
  // to an attacker-supplied host
  const safeNext = resolveNext(url.searchParams.get("next"), url.origin);

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
