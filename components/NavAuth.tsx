"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";

/**
 * Auth-aware nav links.
 *
 * Deliberately a client component: reading the session on the server would
 * make every page that renders this nav dynamic, and the landing page is
 * marketing that should stay statically prerendered. The signed-out variant
 * is the server-rendered default and swaps after hydration.
 */
export default function NavAuth() {
  const [signedIn, setSignedIn] = useState(false);

  useEffect(() => {
    if (!authConfigured) return;
    const supabase = getSupabaseBrowser();
    let active = true;

    supabase.auth.getSession().then(({ data }) => {
      if (active) setSignedIn(Boolean(data.session));
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      if (active) setSignedIn(Boolean(session));
    });

    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
  }, []);

  return (
    <div className="flex items-center gap-3 text-sm">
      <Link
        href="/examples"
        className="glow-hover rounded-lg px-2 py-2 text-muted hover:text-foreground"
      >
        Examples
      </Link>
      <Link
        href="/pricing"
        className="glow-hover rounded-lg px-2 py-2 text-muted hover:text-foreground"
      >
        Pricing
      </Link>
      {signedIn ? (
        <Link
          href="/dashboard"
          className="glow-hover rounded-lg border border-borderline px-4 py-2 text-muted hover:border-cyan hover:text-foreground"
        >
          Your songs
        </Link>
      ) : (
        <>
          <Link
            href="/upload"
            className="glow-hover hidden rounded-lg px-2 py-2 text-muted hover:text-foreground sm:block"
          >
            Free sample clip
          </Link>
          {authConfigured ? (
            <Link
              href="/login"
              className="glow-hover rounded-lg border border-borderline px-4 py-2 font-medium text-foreground hover:border-cyan"
            >
              Log in
            </Link>
          ) : null}
        </>
      )}
    </div>
  );
}
