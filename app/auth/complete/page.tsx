"use client";

import Link from "next/link";
import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Logo from "@/components/Logo";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";
import { resolveNext } from "@/lib/safe-next";

/**
 * Finishes an implicit-flow sign-in. Those links carry the session in the URL
 * fragment, which never reaches the server, so the exchange has to happen here.
 * @supabase/ssr's browser client writes the same cookies the server reads, so
 * once setSession resolves the rest of the app sees a normal session.
 */
function Complete() {
  const router = useRouter();
  const params = useSearchParams();
  const [state, setState] = useState<"working" | "failed">("working");

  useEffect(() => {
    if (!authConfigured) {
      setState("failed");
      return;
    }
    const hash = new URLSearchParams(window.location.hash.replace(/^#/, ""));
    const access_token = hash.get("access_token");
    const refresh_token = hash.get("refresh_token");

    if (!access_token || !refresh_token) {
      setState("failed");
      return;
    }

    let active = true;
    getSupabaseBrowser()
      .auth.setSession({ access_token, refresh_token })
      .then(({ error }) => {
        if (!active) return;
        if (error) {
          setState("failed");
          return;
        }
        // Drop the tokens from the address bar before moving on
        window.history.replaceState(null, "", window.location.pathname);
        router.replace(resolveNext(params.get("next"), window.location.origin));
      })
      .catch(() => active && setState("failed"));

    return () => {
      active = false;
    };
  }, [params, router]);

  if (state === "failed") {
    return (
      <div className="rounded-2xl border border-borderline bg-surface p-8 text-center">
        <h1 className="text-xl font-semibold">That link didn&apos;t work</h1>
        <p className="mx-auto mt-2 max-w-sm text-sm text-muted">
          It may have expired or already been used. Sign-in links are
          single-use.
        </p>
        <Link
          href="/login"
          className="brand-gradient mt-6 inline-block rounded-xl px-6 py-3 text-sm font-semibold text-white transition hover:opacity-90"
        >
          Get a new link
        </Link>
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-borderline bg-surface p-8 text-center">
      <p className="text-sm text-muted">Signing you in…</p>
    </div>
  );
}

export default function CompletePage() {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col px-6">
      <header className="py-6">
        <Link href="/" className="inline-flex rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan">
          <Logo size={26} />
        </Link>
      </header>
      <section className="pt-16">
        <Suspense
          fallback={
            <div className="rounded-2xl border border-borderline bg-surface p-8 text-center">
              <p className="text-sm text-muted">Signing you in…</p>
            </div>
          }
        >
          <Complete />
        </Suspense>
      </section>
    </main>
  );
}
