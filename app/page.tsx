import Link from "next/link";
import WaitlistForm from "@/components/WaitlistForm";

function Logo() {
  return (
    <span className="inline-flex items-center gap-2 font-semibold tracking-tight">
      <svg width="26" height="26" viewBox="0 0 26 26" fill="none" aria-hidden>
        <rect x="1.5" y="1.5" width="23" height="23" rx="5" stroke="var(--violet)" strokeWidth="2" />
        <path d="M10 8.5L17.5 13L10 17.5V8.5Z" fill="var(--coral)" />
        <path d="M5 13c1.2-2.2 2.2 2.2 3.4 0" stroke="var(--violet)" strokeWidth="1.4" strokeLinecap="round" fill="none" />
      </svg>
      VerseFrame
    </span>
  );
}

const kit = [
  { name: "Lyric clip", detail: "Beat-synced animated lyrics, caption-safe" },
  { name: "Visualizer", detail: "Cover art in motion with waveform pulse" },
  { name: "Canvas loop", detail: "Short looping vertical for streaming profiles" },
  { name: "Teaser", detail: "15s hook clip picked from your strongest moment" },
  { name: "Story + square", detail: "Every ratio: 9:16, 1:1, 16:9 — auto-framed" },
];

const steps = [
  { n: "01", title: "Upload", body: "Your finished song, cover art, and lyrics. That's all we need." },
  { n: "02", title: "We find the moments", body: "Song structure and beat detection pick your strongest 15, 30, and 60 seconds." },
  { n: "03", title: "Get your release kit", body: "A coordinated set of clips in every format — ready to post, not just to edit." },
];

export default function Home() {
  return (
    <main className="mx-auto w-full max-w-5xl flex-1 px-6">
      {/* Nav */}
      <header className="flex items-center justify-between py-6">
        <Logo />
        <Link
          href="/upload"
          className="rounded-lg border border-borderline px-4 py-2 text-sm text-muted transition hover:border-violet hover:text-foreground"
        >
          Get a free sample clip
        </Link>
      </header>

      {/* Hero */}
      <section className="py-16 text-center sm:py-24">
        <p className="mb-4 text-sm font-medium uppercase tracking-[0.2em] text-coral">
          For artists, producers &amp; labels
        </p>
        <h1 className="mx-auto max-w-3xl text-4xl font-bold leading-tight tracking-tight sm:text-6xl">
          Turn every song into a <span className="text-violet">scene</span>.
        </h1>
        <p className="mx-auto mt-6 max-w-2xl text-lg text-muted">
          Upload one song. Get a complete short-form release kit — lyric clips,
          visualizers, canvas loops, and vertical promos — in under 10 minutes.
          No timeline. No editor. No excuses before release day.
        </p>
        <div className="mx-auto mt-10 max-w-2xl">
          <WaitlistForm />
          <p className="mt-3 text-xs text-muted">
            Free while in beta · First 1,000 artists lock founding-year pricing
          </p>
        </div>
      </section>

      {/* How it works */}
      <section className="grid gap-6 py-12 sm:grid-cols-3">
        {steps.map((s) => (
          <div key={s.n} className="rounded-2xl border border-borderline bg-surface p-6">
            <p className="font-mono text-sm text-coral">{s.n}</p>
            <h3 className="mt-2 text-lg font-semibold">{s.title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-muted">{s.body}</p>
          </div>
        ))}
      </section>

      {/* What's in the kit */}
      <section className="py-12">
        <h2 className="text-center text-2xl font-bold tracking-tight sm:text-3xl">
          One upload. <span className="text-violet">Ten assets.</span>
        </h2>
        <p className="mx-auto mt-3 max-w-xl text-center text-muted">
          Everything a release needs to look professional on TikTok, Reels,
          Shorts, and your streaming profiles.
        </p>
        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          {kit.map((item) => (
            <div
              key={item.name}
              className="rounded-xl border border-borderline bg-surface-raised p-4 transition hover:border-violet"
            >
              <p className="font-semibold">{item.name}</p>
              <p className="mt-1 text-xs leading-relaxed text-muted">{item.detail}</p>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="my-16 rounded-3xl border border-borderline bg-gradient-to-br from-surface to-surface-raised p-10 text-center">
        <h2 className="text-2xl font-bold tracking-tight sm:text-3xl">
          Releasing soon? Skip the waitlist.
        </h2>
        <p className="mx-auto mt-3 max-w-xl text-muted">
          Send us one song and we&apos;ll hand-build you a free sample clip from
          our template library — so you can see your music in motion before we open the doors.
        </p>
        <Link
          href="/upload"
          className="mt-8 inline-block rounded-xl bg-violet-strong px-8 py-3 font-semibold text-white transition hover:bg-violet"
        >
          Upload your song
        </Link>
      </section>

      <footer className="flex flex-col items-center gap-2 border-t border-borderline py-8 text-center text-xs text-muted">
        <Logo />
        <p>The video studio built for music releases. · © 2026 VerseFrame Labs</p>
        <p>
          By uploading, you confirm you own the rights to your music and artwork.
        </p>
      </footer>
    </main>
  );
}
