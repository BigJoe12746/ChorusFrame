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
      {signedIn ? (
        <Link
          href="/dashboard"
          className="rounded-lg border border-borderline px-4 py-2 text-muted transition hover:border-cyan hover:text-foreground"
        >
          Your songs
        </Link>
      ) : (
        <>
          <Link
            href="/upload"
            className="px-2 py-2 text-muted transition hover:text-foreground"
          >
            Free sample clip
          </Link>
          {authConfigured ? (
            <Link
              href="/login"
              className="rounded-lg border border-borderline px-4 py-2 font-medium text-foreground transition hover:border-cyan"
            >
              Log in
            </Link>
          ) : null}
        </>
      )}
    </div>
  );
}
