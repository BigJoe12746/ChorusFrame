"use client";

import Link from "next/link";
import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import Logo from "@/components/Logo";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";
import { resolveNext } from "@/lib/safe-next";

const CALLBACK_ERRORS: Record<string, string> = {
  expired: "That sign-in link has expired or was already used. Here's a fresh one.",
  "missing-code": "That link was incomplete. Request a new one below.",
  "not-configured": "Sign-in isn't switched on for this deployment yet.",
};

function LoginForm() {
  const params = useSearchParams();
  const nextParam = params.get("next");
  // hasOwn, not a bare lookup: `?error=__proto__` would otherwise resolve to
  // Object.prototype and crash the render when React tries to display it
  const rawError = params.get("error") ?? "";
  const callbackError = Object.hasOwn(CALLBACK_ERRORS, rawError)
    ? CALLBACK_ERRORS[rawError]
    : undefined;
  const [email, setEmail] = useState("");
  const [artistName, setArtistName] = useState("");
  const [state, setState] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [error, setError] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setState("sending");
    setError("");
    try {
      const supabase = getSupabaseBrowser();
      // Sanitize here too, so a hostile `next` never even reaches the email
      const next = resolveNext(nextParam, window.location.origin);
      const { error: authErr } = await supabase.auth.signInWithOtp({
        email: email.trim().toLowerCase(),
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`,
          data: artistName.trim() ? { artist_name: artistName.trim() } : undefined,
        },
      });
      if (authErr) throw new Error(authErr.message);
      setState("sent");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not send the link");
      setState("error");
    }
  }

  const inputCls =
    "w-full rounded-xl border border-borderline bg-surface px-4 py-3 text-foreground placeholder:text-muted focus:border-cyan focus:outline-none";

  if (!authConfigured) {
    return (
      <div className="rounded-2xl border border-borderline bg-surface p-6 text-center">
        <p className="font-semibold">Sign-in isn&apos;t switched on yet</p>
        <p className="mt-2 text-sm text-muted">
          This deployment is missing its Supabase publishable key. Everything
          else on the site works — you can still{" "}
          <Link href="/upload" className="text-cyan underline underline-offset-4">
            send a song
          </Link>{" "}
          for a free sample clip.
        </p>
      </div>
    );
  }

  if (state === "sent") {
    return (
      <div className="rounded-2xl border border-borderline bg-surface p-8 text-center">
        <p className="text-4xl">📬</p>
        <h2 className="mt-4 text-xl font-semibold">Check your email</h2>
        <p className="mx-auto mt-2 max-w-sm text-sm text-muted">
          We sent a sign-in link to <span className="text-foreground">{email}</span>.
          It expires in an hour. No password to remember — opening the link signs
          you in.
        </p>
        <button
          onClick={() => setState("idle")}
          className="mt-6 text-sm text-cyan underline underline-offset-4"
        >
          Use a different email
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-4">
      {callbackError ? (
        <p className="rounded-xl border border-borderline bg-surface p-3 text-sm text-muted">
          {callbackError}
        </p>
      ) : null}
      <div>
        <label className="mb-1.5 block text-sm font-medium">Email</label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@artist.com"
          className={inputCls}
        />
      </div>
      <div>
        <label className="mb-1.5 block text-sm font-medium">
          Artist name <span className="text-muted">(optional — first time only)</span>
        </label>
        <input
          type="text"
          value={artistName}
          onChange={(e) => setArtistName(e.target.value)}
          placeholder="Your stage name"
          className={inputCls}
        />
      </div>

      {error && <p className="text-sm text-danger">{error}</p>}

      <button
        type="submit"
        disabled={state === "sending"}
        className="brand-gradient rounded-xl px-6 py-3.5 font-semibold text-white transition hover:opacity-90 disabled:opacity-60"
      >
        {state === "sending" ? "Sending…" : "Email me a sign-in link"}
      </button>
      <p className="text-center text-xs text-muted">
        No passwords. We email you a one-time link.
      </p>
    </form>
  );
}

export default function LoginPage() {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col px-6">
      <header className="py-6">
        <Link href="/" className="inline-flex items-center gap-2 text-muted transition hover:text-foreground">
          <span aria-hidden>←</span>
          <Logo size={26} />
        </Link>
      </header>
      <section className="pb-20 pt-8">
        <h1 className="text-3xl font-bold tracking-tight">Sign in</h1>
        <p className="mt-3 text-muted">
          Track your uploads and grab your finished clips.
        </p>
        <div className="mt-8">
          <Suspense fallback={<p className="text-sm text-muted">Loading…</p>}>
            <LoginForm />
          </Suspense>
        </div>
      </section>
    </main>
  );
}
