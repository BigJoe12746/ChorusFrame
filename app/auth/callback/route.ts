import { NextResponse } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { getSupabaseServer } from "@/lib/supabase";
import { resolveNext } from "@/lib/safe-next";
import { recordSignupOnce } from "@/app/api/track/route";

/**
 * A freshly created account arriving here is a signup; a returning artist is
 * not. recordSignupOnce owns that judgement (and the once-only guard) so the
 * fragment flow, which finishes in the browser, reaches the same conclusion.
 */
async function recordArrival(supabase: NonNullable<Awaited<ReturnType<typeof getSupabaseServer>>>) {
  const { data } = await supabase.auth.getUser();
  if (data.user) await recordSignupOnce(data.user.id, data.user.created_at, null);
}

export const runtime = "nodejs";

/**
 * Magic-link landing. Supabase can hand back a session in three shapes
 * depending on the flow the link was minted with:
 *
 *   ?code=…                  PKCE (what @supabase/ssr's browser client uses)
 *   ?token_hash=…&type=…     the {{ .TokenHash }} email-template form
 *   #access_token=…          implicit flow — a fragment, which never reaches
 *                            the server, so it is finished client-side
 *
 * Handling only the first would strand anyone whose link arrives in another
 * shape on "missing-code" with no way to sign in.
 */
export async function GET(request: Request) {
  const url = new URL(request.url);
  // Only allow same-origin redirects — never bounce a freshly signed-in user
  // to an attacker-supplied host
  const safeNext = resolveNext(url.searchParams.get("next"), url.origin);
  const code = url.searchParams.get("code");
  const tokenHash = url.searchParams.get("token_hash");
  const type = url.searchParams.get("type") as EmailOtpType | null;

  const supabase = await getSupabaseServer();
  if (!supabase) {
    return NextResponse.redirect(new URL("/login?error=not-configured", url.origin));
  }

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) {
      return NextResponse.redirect(new URL("/login?error=expired", url.origin));
    }
    await recordArrival(supabase);
    return NextResponse.redirect(new URL(safeNext, url.origin));
  }

  if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type });
    if (error) {
      return NextResponse.redirect(new URL("/login?error=expired", url.origin));
    }
    await recordArrival(supabase);
    return NextResponse.redirect(new URL(safeNext, url.origin));
  }

  // No query credentials. The token may be in the fragment, which only the
  // browser can read — hand off to the client page, which preserves it.
  const complete = new URL("/auth/complete", url.origin);
  complete.searchParams.set("next", safeNext);
  return NextResponse.redirect(complete);
}
