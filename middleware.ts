import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";
const configured = Boolean(url && publishableKey && !publishableKey.includes("PASTE"));

/**
 * Refreshes the auth session cookie on every request so Server Components
 * always see a valid session, and gates /dashboard behind sign-in.
 */
export async function middleware(request: NextRequest) {
  if (!configured) return NextResponse.next();

  // A sign-in code that landed somewhere other than the callback.
  //
  // Supabase falls back to the project's Site URL whenever the requested
  // redirect isn't allow-listed, which drops the artist on "/" with a bare
  // ?code= and no handler — the link looks broken. Stale links carry their
  // old destination forever, so this keeps working regardless of how the
  // dashboard is configured today.
  const { pathname, searchParams } = request.nextUrl;
  const strayCode = searchParams.get("code") ?? searchParams.get("token_hash");
  if (strayCode && !pathname.startsWith("/auth/")) {
    const callback = request.nextUrl.clone();
    callback.pathname = "/auth/callback";
    // Preserve the original path as the destination when it was a real page
    if (pathname !== "/" && !callback.searchParams.get("next")) {
      callback.searchParams.set("next", pathname);
    }
    return NextResponse.redirect(callback);
  }

  let response = NextResponse.next({ request });

  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (list) => {
        for (const { name, value } of list) request.cookies.set(name, value);
        response = NextResponse.next({ request });
        for (const { name, value, options } of list) {
          response.cookies.set(name, value, options);
        }
      },
    },
  });

  // getUser() revalidates the token with Supabase — don't trust getSession() here
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user && request.nextUrl.pathname.startsWith("/dashboard")) {
    const redirect = request.nextUrl.clone();
    redirect.pathname = "/login";
    redirect.searchParams.set("next", request.nextUrl.pathname);
    const res = NextResponse.redirect(redirect);
    // Carry over any cookies Supabase queued during the refresh attempt —
    // otherwise a revoked session's cookie-clearing is thrown away here and
    // the dead cookie keeps triggering failed refreshes on every request.
    for (const cookie of response.cookies.getAll()) res.cookies.set(cookie);
    return res;
  }

  return response;
}

export const config = {
  matcher: [
    // Everything except static assets and image files
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|wav|mp3|mp4)$).*)",
  ],
};
