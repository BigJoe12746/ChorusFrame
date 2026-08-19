"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import FileField from "@/components/FileField";
import Logo from "@/components/Logo";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";

const MAX_AUDIO = 50 * 1024 * 1024;
const MAX_ART = 10 * 1024 * 1024;
const AUDIO_TYPES = ["audio/mpeg", "audio/wav", "audio/x-wav", "audio/mp3"];
const ART_TYPES = ["image/jpeg", "image/png", "image/webp"];

export default function UploadPage() {
  const router = useRouter();
  const formRef = useRef<HTMLFormElement>(null);
  const [state, setState] = useState<"idle" | "sending" | "done" | "error">("idle");
  const [error, setError] = useState("");
  const [progress, setProgress] = useState(0);
  const [email, setEmail] = useState("");
  const [lyrics, setLyrics] = useState("");
  /** Signed-in artists render for themselves; anonymous ones wait for us. */
  const [signedIn, setSignedIn] = useState(false);

  // Signed-in artists shouldn't have to retype an address we already know
  useEffect(() => {
    if (!authConfigured) return;
    let live = true;
    getSupabaseBrowser()
      .auth.getUser()
      .then(({ data }) => {
        // getUser() is a network round-trip, so this can land after the artist
        // has already typed. Never overwrite what they entered — they may be
        // sending the clip to a different address than their login.
        if (!live || !data.user) return;
        setSignedIn(true);
        if (data.user.email) setEmail((cur) => cur || data.user!.email!);
      })
      .catch(() => {});
    return () => {
      live = false;
    };
  }, []);

  /** PUT straight to storage, reporting progress as it goes. */
  function putFile(signedUrl: string, file: File, onProgress: (pct: number) => void) {
    return new Promise<void>((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open("PUT", signedUrl);
      xhr.setRequestHeader("content-type", file.type || "application/octet-stream");
      xhr.upload.addEventListener("progress", (ev) => {
        if (ev.lengthComputable) onProgress(ev.loaded / ev.total);
      });
      xhr.addEventListener("load", () =>
        xhr.status >= 200 && xhr.status < 300
          ? resolve()
          : reject(new Error(`upload failed (${xhr.status})`))
      );
      xhr.addEventListener("error", () => reject(new Error("network")));
      xhr.addEventListener("abort", () => reject(new Error("aborted")));
      xhr.send(file);
    });
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const form = formRef.current;
    if (!form) return;

    const data = new FormData(form);
    const song = data.get("song");
    const artwork = data.get("artwork");
    if (!(song instanceof File) || song.size === 0) {
      setError("Attach your song first.");
      setState("error");
      return;
    }

    setState("sending");
    setError("");
    setProgress(0);

    try {
      // 1. Ask for somewhere to put the files. The audio must NOT go through
      //    our API: Vercel rejects request bodies over ~4.5MB, which is
      //    smaller than most songs.
      const urlRes = await fetch("/api/submissions/upload-url", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          songName: song.name,
          artworkName: artwork instanceof File && artwork.size > 0 ? artwork.name : undefined,
        }),
      });
      const slots = await urlRes.json();
      if (!urlRes.ok) throw new Error(slots.error || "Could not start the upload");

      // 2. Straight to storage. The song is the bulk of the bytes, so it owns
      //    most of the progress bar.
      const hasArt = artwork instanceof File && artwork.size > 0 && slots.artwork;
      await putFile(slots.song.signedUrl, song, (f) =>
        setProgress(Math.round(f * (hasArt ? 90 : 98)))
      );
      if (hasArt) {
        await putFile(slots.artwork.signedUrl, artwork as File, (f) =>
          setProgress(90 + Math.round(f * 8))
        );
      }
      setProgress(99);

      // 3. Record it, now that the files are demonstrably there.
      const finishRes = await fetch("/api/submissions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          id: slots.id,
          email: String(data.get("email") ?? ""),
          artistName: String(data.get("artistName") ?? ""),
          songTitle: String(data.get("songTitle") ?? ""),
          lyrics: String(data.get("lyrics") ?? ""),
          songPath: slots.song.path,
          artworkPath: hasArt ? slots.artwork.path : null,
        }),
      });
      const finished = await finishRes.json();
      if (!finishRes.ok) throw new Error(finished.error || "Something went wrong. Try again.");

      setProgress(100);

      // A signed-in artist can render this themselves in minutes. Leaving them
      // on a "we'll email you in a few days" screen would be plainly untrue,
      // and the button they need is on the dashboard — so take them to it with
      // this song's picker already open.
      if (signedIn) {
        router.push(`/dashboard?new=${encodeURIComponent(slots.id)}`);
        router.refresh();
        return;
      }
      setState("done");
    } catch (err) {
      setError(
        err instanceof Error && err.message !== "network"
          ? err.message
          : "The upload was interrupted. Check your connection and try again."
      );
      setState("error");
    }
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
            Got it — we&apos;ll build your clip by hand.
          </h1>
          <p className="mx-auto mt-4 max-w-md text-muted">
            We&apos;ll make a sample clip from your song and email it to{" "}
            <span className="text-foreground">{email}</span> within a few days.
          </p>
          <p className="mx-auto mt-3 max-w-md text-sm text-muted">
            Don&apos;t want to wait?{" "}
            <Link href="/login" className="text-cyan underline underline-offset-4">
              Make an account
            </Link>{" "}
            and you can render your own clips in minutes.
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
          {signedIn ? (
            <>
              <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
                Add a song to your library
              </h1>
              <p className="mt-3 text-muted">
                Upload a finished song and it lands on your dashboard, ready to
                pick a hook and render every format.
              </p>
            </>
          ) : (
            <>
              <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
                Get a free sample clip
              </h1>
              <p className="mt-3 text-muted">
                Upload one finished song and we&apos;ll send back a short promo
                clip built from our template library — free, no strings. Make an
                account with this email afterwards and the song appears in your
                dashboard automatically.
              </p>
            </>
          )}

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
                  — paste the part you want on screen, usually the chorus
                </span>
              </label>
              <textarea
                id="lyrics"
                name="lyrics"
                rows={5}
                value={lyrics}
                onChange={(e) => setLyrics(e.target.value)}
                placeholder={"Late checkout, I'm still here\nSay my name, make it clear"}
                className={inputCls}
              />
              {/* Skipping this silently produces a visualizer instead of a
                  lyric video, which is not what anyone comes here for. */}
              {!lyrics.trim() ? (
                <p className="mt-1.5 text-xs text-muted">
                  Leave this empty and you&apos;ll get a{" "}
                  <span className="text-foreground">visualizer</span> — cover art and
                  waveform, no words. You can add lyrics later from your dashboard.
                </p>
              ) : null}
            </div>

            <label className="flex items-start gap-3 text-sm text-muted">
              <input
                type="checkbox"
                required
                className="mt-0.5 h-4 w-4 shrink-0 accent-[var(--violet-strong)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
              />
              <span>
                I own or control the rights to this music and artwork, and I&apos;m okay
                with ChorusFrame using them to build my clips. I agree to the{" "}
                <Link href="/legal/terms" className="text-cyan underline underline-offset-4">
                  Terms
                </Link>{" "}
                and{" "}
                <Link href="/legal/privacy" className="text-cyan underline underline-offset-4">
                  Privacy policy
                </Link>
                .
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
