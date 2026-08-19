"use client";

import Link from "next/link";
import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Logo from "@/components/Logo";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";
import { resolveNext } from "@/lib/safe-next";

const CALLBACK_ERRORS: Record<string, string> = {
  expired: "That sign-in link has expired or was already used. Here's a fresh one.",
  "missing-code": "That link was incomplete. Request a new one below.",
  "not-configured": "Sign-in isn't switched on for this deployment yet.",
};

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const nextParam = params.get("next");
  const rawError = params.get("error") ?? "";
  const callbackError = Object.hasOwn(CALLBACK_ERRORS, rawError)
    ? CALLBACK_ERRORS[rawError]
    : undefined;

  // Password is the default: an artist who has one shouldn't have to go via
  // their inbox every single time.
  const isNew = params.get("new") === "1";
  const [mode, setMode] = useState<"password" | "link">(isNew ? "link" : "password");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [artistName, setArtistName] = useState("");
  const [state, setState] = useState<"idle" | "sending" | "sent" | "error">("idle");
  const [error, setError] = useState("");

  useEffect(() => {
    if (!authConfigured) return;
    getSupabaseBrowser()
      .auth.getSession()
      .then(({ data }) => {
        if (data.session) {
          router.replace(resolveNext(nextParam, window.location.origin));
        }
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function signInWithPassword(e: React.FormEvent) {
    e.preventDefault();
    setState("sending");
    setError("");
    try {
      const { error: authErr } = await getSupabaseBrowser().auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      });
      if (authErr) throw new Error(authErr.message);
      router.push(resolveNext(nextParam, window.location.origin));
      router.refresh();
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Could not sign you in";
      setError(
        /invalid login/i.test(msg)
          ? "That email and password don't match. If you've never set a password, use the email link instead."
          : msg
      );
      setState("error");
    }
  }

  async function sendLink(e: React.FormEvent) {
    e.preventDefault();
    setState("sending");
    setError("");
    try {
      const next = resolveNext(nextParam, window.location.origin);
      const { error: authErr } = await getSupabaseBrowser().auth.signInWithOtp({
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
    "w-full rounded-xl border border-borderline bg-surface px-4 py-3 text-foreground placeholder:text-muted transition focus:border-cyan focus:outline-none focus:ring-2 focus:ring-cyan/40";

  if (!authConfigured) {
    return (
      <div className="rounded-2xl border border-borderline bg-surface p-6 text-center">
        <p className="font-semibold">Sign-in isn&apos;t switched on yet</p>
        <p className="mt-2 text-sm text-muted">
          This deployment is missing its Supabase publishable key. You can still{" "}
          <Link href="/upload" className="text-cyan underline underline-offset-4">
            send a song
          </Link>
          .
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
          We sent a sign-in link to <span className="text-foreground">{email}</span>. It
          expires in an hour. Once you&apos;re in, set a password from your dashboard so
          you can skip the inbox next time.
        </p>
        <button
          onClick={() => setState("idle")}
          className="mt-6 text-sm text-cyan underline underline-offset-4"
        >
          Back
        </button>
      </div>
    );
  }

  return (
    <div>
      {/* Mode switch */}
      <div className="mb-5 flex gap-1 rounded-xl border border-borderline bg-surface p-1">
        {(["password", "link"] as const).map((m) => (
          <button
            key={m}
            type="button"
            onClick={() => {
              setMode(m);
              setError("");
            }}
            className={`flex-1 rounded-lg px-3 py-2 text-sm transition ${
              mode === m
                ? "bg-surface-raised font-medium text-foreground"
                : "text-muted hover:text-foreground"
            }`}
          >
            {m === "password" ? "Password" : "Email link"}
          </button>
        ))}
      </div>

      {callbackError ? (
        <p className="mb-4 rounded-xl border border-borderline bg-surface p-3 text-sm text-muted">
          {callbackError}
        </p>
      ) : null}

      <form
        onSubmit={mode === "password" ? signInWithPassword : sendLink}
        className="flex flex-col gap-4"
      >
        <div>
          <label htmlFor="email" className="mb-1.5 block text-sm font-medium">
            Email
          </label>
          <input
            id="email"
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@artist.com"
            className={inputCls}
          />
        </div>

        {mode === "password" ? (
          <div>
            <label htmlFor="password" className="mb-1.5 block text-sm font-medium">
              Password
            </label>
            <input
              id="password"
              type="password"
              required
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Your password"
              className={inputCls}
            />
          </div>
        ) : (
          <div>
            <label htmlFor="artistName" className="mb-1.5 block text-sm font-medium">
              Artist name{" "}
              <span className="font-normal text-muted">(optional — first time only)</span>
            </label>
            <input
              id="artistName"
              type="text"
              value={artistName}
              onChange={(e) => setArtistName(e.target.value)}
              placeholder="Your stage name"
              className={inputCls}
            />
          </div>
        )}

        {error ? (
          <p role="alert" className="text-sm text-danger">
            {error}
          </p>
        ) : null}

        <button
          type="submit"
          disabled={state === "sending"}
          className="brand-gradient rounded-xl px-6 py-3.5 font-semibold text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan disabled:opacity-60"
        >
          {state === "sending"
            ? mode === "password"
              ? "Signing in…"
              : "Sending…"
            : mode === "password"
              ? "Log in"
              : "Email me a sign-in link"}
        </button>

        <p className="text-center text-xs text-muted">
          {mode === "password"
            ? "No password yet? Use the email link once, then set one from your dashboard."
            : "We email you a one-time link — no password needed."}
        </p>
      </form>
    </div>
  );
}

function LoginHeading() {
  const params = useSearchParams();
  const isNew = params.get("new") === "1";
  return (
    <>
      <h1 className="text-3xl font-bold tracking-tight">
        {isNew ? "Create your account" : "Log in"}
      </h1>
      <p className="mt-3 text-muted">
        {isNew
          ? "The email link creates your account — no password needed."
          : "Track your songs and grab your finished clips."}
      </p>
    </>
  );
}

export default function LoginPage() {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col px-6">
      <header className="py-6">
        <Link
          href="/"
          className="inline-flex items-center gap-2 rounded-lg text-muted transition hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan"
        >
          <span aria-hidden>←</span>
          <Logo size={26} />
        </Link>
      </header>
      <section className="pb-20 pt-8">
        <Suspense fallback={null}>
          <LoginHeading />
        </Suspense>
        <div className="mt-8">
          <Suspense fallback={<p className="text-sm text-muted">Loading…</p>}>
            <LoginForm />
          </Suspense>
        </div>
      </section>
    </main>
  );
}
