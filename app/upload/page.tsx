"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import FileField from "@/components/FileField";
import Logo from "@/components/Logo";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";

const MAX_AUDIO = 50 * 1024 * 1024;
const MAX_ART = 10 * 1024 * 1024;
const AUDIO_TYPES = ["audio/mpeg", "audio/wav", "audio/x-wav", "audio/mp3"];
const ART_TYPES = ["image/jpeg", "image/png", "image/webp"];

export default function UploadPage() {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, setState] = useState<"idle" | "sending" | "done" | "error">("idle");
  const [error, setError] = useState("");
  const [progress, setProgress] = useState(0);
  const [email, setEmail] = useState("");

  // Signed-in artists shouldn't have to retype an address we already know
  useEffect(() => {
    if (!authConfigured) return;
    let live = true;
    getSupabaseBrowser()
      .auth.getUser()
      .then(({ data }) => {
        if (live && data.user?.email) setEmail(data.user.email);
      })
      .catch(() => {});
    return () => {
      live = false;
    };
  }, []);

  function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!formRef.current) return;
    setState("sending");
    setError("");
    setProgress(0);

    // XHR rather than fetch: a 50 MB upload with no progress feels broken
    const xhr = new XMLHttpRequest();
    xhr.open("POST", "/api/submissions");
    xhr.upload.addEventListener("progress", (ev) => {
      if (ev.lengthComputable) setProgress(Math.round((ev.loaded / ev.total) * 100));
    });
    xhr.addEventListener("load", () => {
      let data: { error?: string } = {};
      try {
        data = JSON.parse(xhr.responseText);
      } catch {
        // fall through to the status check
      }
      if (xhr.status >= 200 && xhr.status < 300) setState("done");
      else {
        setError(data.error || "Something went wrong. Try again.");
        setState("error");
      }
    });
    xhr.addEventListener("error", () => {
      setError("The upload was interrupted. Check your connection and try again.");
      setState("error");
    });
    xhr.send(new FormData(formRef.current));
  }

  const inputCls =
    "w-full rounded-xl border border-borderline bg-surface px-4 py-3 text-foreground placeholder:text-muted transition focus:border-cyan focus:outline-none focus:ring-2 focus:ring-cyan/40";

  return (
    <main className="mx-auto w-full max-w-2xl flex-1 px-6">
      <header className="py-6">
        <Link
          href="/"
          className="inline-flex items-center gap-2 rounded-lg text-muted transition hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan"
        >
          <span aria-hidden>←</span>
          <Logo size={26} />
        </Link>
      </header>

      {state === "done" ? (
        <section className="py-24 text-center">
          <p className="text-5xl">🎬</p>
          <h1 className="mt-6 text-3xl font-bold tracking-tight">
            Got it. Your clip is in the queue.
          </h1>
          <p className="mx-auto mt-4 max-w-md text-muted">
            We&apos;ll build a sample clip from your song and email it to you within a
            few days. Keep an eye on your inbox.
          </p>
          <Link
            href="/"
            className="mt-8 inline-block rounded-xl border border-borderline px-6 py-3 text-sm transition hover:border-cyan focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
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
            Upload one finished song and we&apos;ll send back a short promo clip — free,
            no strings.
          </p>

          <form ref={formRef} onSubmit={submit} className="mt-10 flex flex-col gap-5">
            <div className="grid gap-5 sm:grid-cols-2">
              <div>
                <label htmlFor="email" className="mb-1.5 block text-sm font-medium">
                  Email
                </label>
                <input
                  id="email"
                  name="email"
                  type="email"
                  required
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@artist.com"
                  className={inputCls}
                />
              </div>
              <div>
                <label htmlFor="artistName" className="mb-1.5 block text-sm font-medium">
                  Artist name
                </label>
                <input
                  id="artistName"
                  name="artistName"
                  type="text"
                  placeholder="Your stage name"
                  className={inputCls}
                />
              </div>
            </div>

            <div>
              <label htmlFor="songTitle" className="mb-1.5 block text-sm font-medium">
                Song title
              </label>
              <input
                id="songTitle"
                name="songTitle"
                type="text"
                required
                placeholder="What's the track called?"
                className={inputCls}
              />
            </div>

            <FileField
              name="song"
              label="Song file"
              hint="(WAV or MP3, max 50 MB)"
              accept=".mp3,.wav,audio/mpeg,audio/wav"
              acceptTypes={AUDIO_TYPES}
              maxBytes={MAX_AUDIO}
              required
              icon="🎵"
            />

            <FileField
              name="artwork"
              label="Cover artwork"
              hint="(optional — JPG, PNG or WebP, max 10 MB)"
              accept=".jpg,.jpeg,.png,.webp,image/jpeg,image/png,image/webp"
              acceptTypes={ART_TYPES}
              maxBytes={MAX_ART}
              icon="🖼️"
            />

            <div>
              <label htmlFor="lyrics" className="mb-1.5 block text-sm font-medium">
                Lyrics{" "}
                <span className="font-normal text-muted">
                  (optional — paste the section you want on screen)
                </span>
              </label>
              <textarea
                id="lyrics"
                name="lyrics"
                rows={5}
                placeholder="Paste your hook or chorus…"
                className={inputCls}
              />
            </div>

            <label className="flex items-start gap-3 text-sm text-muted">
              <input
                type="checkbox"
                required
                className="mt-0.5 h-4 w-4 shrink-0 accent-[var(--violet-strong)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
              />
              <span>
                I own or control the rights to this music and artwork, and I&apos;m okay
                with ChorusFrame using them to build my sample clip.
              </span>
            </label>

            {error ? (
              <p role="alert" className="text-sm text-danger">
                {error}
              </p>
            ) : null}

            <button
              type="submit"
              disabled={state === "sending"}
              className="brand-gradient rounded-xl px-6 py-3.5 font-semibold text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan disabled:opacity-70"
            >
              {state === "sending"
                ? progress > 0 && progress < 100
                  ? `Uploading… ${progress}%`
                  : "Finishing up…"
                : "Send my song"}
            </button>

            {state === "sending" ? (
              <div
                className="h-1.5 w-full overflow-hidden rounded-full bg-surface-raised"
                role="progressbar"
                aria-valuenow={progress}
                aria-valuemin={0}
                aria-valuemax={100}
                aria-label="Upload progress"
              >
                <div
                  className="brand-gradient h-full transition-all duration-200"
                  style={{ width: `${progress}%` }}
                />
              </div>
            ) : null}
          </form>
        </section>
      )}
    </main>
  );
}
