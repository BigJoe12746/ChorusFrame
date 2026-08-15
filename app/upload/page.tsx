"use client";

import Link from "next/link";
import { useRef, useState } from "react";

export default function UploadPage() {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, setState] = useState<"idle" | "sending" | "done" | "error">("idle");
  const [error, setError] = useState("");
  const [songName, setSongName] = useState("");
  const [artName, setArtName] = useState("");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!formRef.current) return;
    setState("sending");
    setError("");
    try {
      const res = await fetch("/api/submissions", {
        method: "POST",
        body: new FormData(formRef.current),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Something went wrong");
      setState("done");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
      setState("error");
    }
  }

  const inputCls =
    "w-full rounded-xl border border-borderline bg-surface px-4 py-3 text-foreground placeholder:text-muted focus:border-violet focus:outline-none";
  const fileCls =
    "w-full cursor-pointer rounded-xl border border-dashed border-borderline bg-surface px-4 py-6 text-center text-sm text-muted transition hover:border-violet";

  return (
    <main className="mx-auto w-full max-w-2xl flex-1 px-6">
      <header className="flex items-center justify-between py-6">
        <Link href="/" className="font-semibold tracking-tight">
          ← VerseFrame
        </Link>
      </header>

      {state === "done" ? (
        <section className="py-24 text-center">
          <p className="text-5xl">🎬</p>
          <h1 className="mt-6 text-3xl font-bold tracking-tight">Got it. Your clip is in the queue.</h1>
          <p className="mx-auto mt-4 max-w-md text-muted">
            We&apos;ll hand-build a sample clip from your song and email it to you
            within a few days. Keep an eye on your inbox.
          </p>
          <Link
            href="/"
            className="mt-8 inline-block rounded-xl border border-borderline px-6 py-3 text-sm transition hover:border-violet"
          >
            Back to home
          </Link>
        </section>
      ) : (
        <section className="pb-20 pt-8">
          <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
            Get a free sample clip
          </h1>
          <p className="mt-3 text-muted">
            Upload one finished song and we&apos;ll send back a short promo clip
            built from our template library — free, no strings.
          </p>

          <form ref={formRef} onSubmit={submit} className="mt-10 flex flex-col gap-5">
            <div className="grid gap-5 sm:grid-cols-2">
              <div>
                <label className="mb-1.5 block text-sm font-medium">Email</label>
                <input name="email" type="email" required placeholder="you@artist.com" className={inputCls} />
              </div>
              <div>
                <label className="mb-1.5 block text-sm font-medium">Artist name</label>
                <input name="artistName" type="text" placeholder="Your stage name" className={inputCls} />
              </div>
            </div>

            <div>
              <label className="mb-1.5 block text-sm font-medium">Song title</label>
              <input name="songTitle" type="text" required placeholder="What's the track called?" className={inputCls} />
            </div>

            <div>
              <label className="mb-1.5 block text-sm font-medium">
                Song file <span className="text-muted">(WAV or MP3, max 50 MB)</span>
              </label>
              <label className={fileCls}>
                {songName || "Click to choose your song"}
                <input
                  name="song"
                  type="file"
                  required
                  accept=".mp3,.wav,audio/mpeg,audio/wav"
                  className="hidden"
                  onChange={(e) => setSongName(e.target.files?.[0]?.name ?? "")}
                />
              </label>
            </div>

            <div>
              <label className="mb-1.5 block text-sm font-medium">
                Cover artwork <span className="text-muted">(optional — JPG/PNG, max 10 MB)</span>
              </label>
              <label className={fileCls}>
                {artName || "Click to choose your artwork"}
                <input
                  name="artwork"
                  type="file"
                  accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp"
                  className="hidden"
                  onChange={(e) => setArtName(e.target.files?.[0]?.name ?? "")}
                />
              </label>
            </div>

            <div>
              <label className="mb-1.5 block text-sm font-medium">
                Lyrics <span className="text-muted">(optional — paste the section you want on screen)</span>
              </label>
              <textarea name="lyrics" rows={5} placeholder="Paste your hook or chorus…" className={inputCls} />
            </div>

            <label className="flex items-start gap-3 text-sm text-muted">
              <input type="checkbox" required className="mt-1 accent-[var(--violet-strong)]" />
              I own or control the rights to this music and artwork, and I&apos;m
              okay with VerseFrame using them to build my sample clip.
            </label>

            {error && <p className="text-sm text-coral">{error}</p>}

            <button
              type="submit"
              disabled={state === "sending"}
              className="rounded-xl bg-violet-strong px-6 py-3.5 font-semibold text-white transition hover:bg-violet disabled:opacity-60"
            >
              {state === "sending" ? "Uploading…" : "Send my song"}
            </button>
          </form>
        </section>
      )}
    </main>
  );
}
