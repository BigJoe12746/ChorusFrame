"use client";

import { useState } from "react";

export default function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [artistName, setArtistName] = useState("");
  const [state, setState] = useState<"idle" | "sending" | "done" | "error">("idle");
  const [error, setError] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setState("sending");
    setError("");
    try {
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, artistName }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Something went wrong");
      setState("done");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
      setState("error");
    }
  }

  if (state === "done") {
    return (
      <div className="rounded-xl border border-borderline bg-surface p-6 text-center">
        <p className="text-lg font-semibold">You&apos;re on the list. 🎬</p>
        <p className="mt-2 text-sm text-muted">
          We&apos;ll email you when your spot opens. Want to skip the line?{" "}
          <a href="/upload" className="text-cyan underline underline-offset-4">
            Send us a song
          </a>{" "}
          and we&apos;ll cut you a free sample clip.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-3 sm:flex-row sm:items-stretch">
      <input
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="you@artist.com"
        aria-label="Email address"
        className="flex-1 rounded-xl border border-borderline bg-surface px-4 py-3 text-foreground placeholder:text-muted focus:border-violet focus:outline-none"
      />
      <input
        type="text"
        value={artistName}
        onChange={(e) => setArtistName(e.target.value)}
        placeholder="Artist name (optional)"
        aria-label="Artist name"
        className="flex-1 rounded-xl border border-borderline bg-surface px-4 py-3 text-foreground placeholder:text-muted focus:border-violet focus:outline-none"
      />
      <button
        type="submit"
        disabled={state === "sending"}
        className="brand-gradient rounded-xl px-6 py-3 font-semibold text-white transition hover:opacity-90 disabled:opacity-60"
      >
        {state === "sending" ? "Joining…" : "Join the waitlist"}
      </button>
      {error && <p className="text-sm text-danger sm:self-center">{error}</p>}
    </form>
  );
}
