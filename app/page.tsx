import Link from "next/link";
import Logo from "@/components/Logo";
import NavAuth from "@/components/NavAuth";
import { FOUNDING, money } from "@/lib/plans";

const kit = [
  { name: "TikTok / Reels / Shorts", detail: "9:16 vertical, caption-safe zones" },
  { name: "Square post", detail: "1:1 for feed and carousels" },
  { name: "Lyric video", detail: "Wide 16:9 cut for YouTube" },
  { name: "Visualizer", detail: "Cover art in motion when you skip the lyrics" },
  { name: "Teasers", detail: "Any length from 5 to 60 seconds" },
];

const steps = [
  {
    n: "01",
    title: "Upload",
    body: "Your mastered song, cover art, and the official lyrics. That's the whole setup.",
  },
  {
    n: "02",
    title: "We read the song",
    body: "Tempo, beats, and energy get read automatically — the clip opens on your strongest moment.",
  },
  {
    n: "03",
    title: "Pick a vibe",
    body: "Hyperpop, dark anime, dreamy, cinematic, reggae, minimal. You get several directions, not one guess.",
  },
  {
    n: "04",
    title: "Fix timing in seconds",
    body: "Tap-to-sync on the waveform. Nudge a word or a line — no timeline editing required.",
  },
  {
    n: "05",
    title: "Export the campaign",
    body: "9:16, 1:1 and 16:9 from one project, in one pass.",
  },
];

const promises = [
  "You always know what an export costs before you run it.",
  "Failed renders never consume exports.",
  "Your projects are never deleted out from under you.",
  "Your master audio stays at full quality.",
  "The preview matches the export.",
  "Every release format comes from one project.",
  "Paste your real lyrics — tap them into time once, no timeline editing.",
];

export default function Home() {
  return (
    <main className="mx-auto w-full max-w-5xl flex-1 px-6">
      {/* Nav */}
      <header className="flex items-center justify-between py-6">
        <Logo />
        <NavAuth />
      </header>

      {/* Hero */}
      <section className="py-16 text-center sm:py-24">
        <p className="mb-4 text-sm font-medium uppercase tracking-[0.2em] text-cyan">
          For artists, producers &amp; labels
        </p>
        <h1 className="mx-auto max-w-3xl text-4xl font-bold leading-tight tracking-tight sm:text-6xl">
          Upload one song. Get your entire{" "}
          <span className="brand-text">release campaign</span>.
        </h1>
        <p className="mx-auto mt-6 max-w-2xl text-lg text-muted">
          Song, cover, lyrics in — platform-ready videos out. Vertical cuts,
          square posts, a widescreen lyric video, visualizers, teasers. One
          project, three formats, minutes instead of a weekend.
        </p>
        <div className="mx-auto mt-10 flex max-w-2xl flex-col items-center gap-4">
          <Link
            href="/login?new=1"
            className="glow-hover-strong brand-gradient rounded-xl px-8 py-3.5 text-base font-semibold text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
          >
            Start free — upload a song
          </Link>
          <p className="text-sm text-muted">
            Rather we made your first one?{" "}
            <Link
              href="/upload"
              className="text-cyan underline underline-offset-4 transition hover:text-foreground"
            >
              Send us a song
            </Link>{" "}
            and we&apos;ll build it by hand.
          </p>
          <p className="text-xs text-muted">
            Free plan, no card ·{" "}
            <Link href="/pricing" className="underline underline-offset-4 transition hover:text-foreground">
              Pro is $10 a month
            </Link>{" "}
            when you need more
          </p>
          <p className="text-xs text-cyan">
            <Link href="/pricing" className="underline underline-offset-4">
              Founding year: the first {FOUNDING.seats.toLocaleString()} artists get Pro
              for {money(FOUNDING.priceCents)} — and keep that price
            </Link>
          </p>
        </div>
      </section>

      {/* The product's output, not a description of it. Same demo song,
          three of the ten templates — muted loops, tap for sound. */}
      <section className="py-12">
        <h2 className="text-center text-2xl font-bold tracking-tight sm:text-3xl">
          Same song. <span className="brand-text">Three of ten templates.</span>
        </h2>
        <p className="mx-auto mt-3 max-w-xl text-center text-muted">
          Rendered by the exact pipeline your songs go through — nothing staged.{" "}
          <Link href="/examples" className="text-cyan underline underline-offset-4 transition hover:text-foreground">
            See all six examples
          </Link>
        </p>
        <div className="mx-auto mt-8 grid max-w-3xl grid-cols-3 gap-3 sm:gap-4">
          {[
            { id: "hyperpop", label: "Hyperpop" },
            { id: "anime", label: "Dark anime" },
            { id: "minimal", label: "Minimal" },
          ].map((d) => (
            <figure key={d.id} className="flex flex-col gap-2">
              <video
                src={`/demo/clips/${d.id}.mp4`}
                autoPlay
                muted
                loop
                playsInline
                preload="metadata"
                className="w-full rounded-xl border border-borderline bg-surface"
                style={{ aspectRatio: "9 / 16" }}
              />
              <figcaption className="text-center text-xs text-muted">{d.label}</figcaption>
            </figure>
          ))}
        </div>
      </section>

      {/* How it works */}
      <section className="py-12">
        <h2 className="text-center text-2xl font-bold tracking-tight sm:text-3xl">
          How it works
        </h2>
        <div className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-5">
          {steps.map((s) => (
            <div
              key={s.n}
              className="rounded-2xl border border-borderline bg-surface p-6"
            >
              <p className="font-mono text-sm text-cyan">{s.n}</p>
              <h3 className="mt-2 text-lg font-semibold">{s.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted">{s.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* What's in the kit */}
      <section className="py-12">
        <h2 className="text-center text-2xl font-bold tracking-tight sm:text-3xl">
          One upload. <span className="brand-text">The whole campaign.</span>
        </h2>
        <p className="mx-auto mt-3 max-w-xl text-center text-muted">
          Everything a release needs, sized correctly for where it&apos;s going.
        </p>
        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {kit.map((item) => (
            <div
              key={item.name}
              className="glow-hover rounded-xl border border-borderline bg-surface-raised p-4 hover:border-cyan"
            >
              <p className="font-semibold">{item.name}</p>
              <p className="mt-1 text-xs leading-relaxed text-muted">
                {item.detail}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* Promises */}
      <section className="py-12">
        <h2 className="text-center text-2xl font-bold tracking-tight sm:text-3xl">
          What we promise
        </h2>
        <p className="mx-auto mt-3 max-w-xl text-center text-muted">
          Creative tools have trained artists to expect surprises. These are the
          rules we&apos;re building to.
        </p>
        <ul className="mx-auto mt-8 grid max-w-3xl gap-3 sm:grid-cols-2">
          {promises.map((p) => (
            <li
              key={p}
              className="flex items-start gap-3 rounded-xl border border-borderline bg-surface p-4 text-sm"
            >
              <span className="mt-0.5 text-cyan" aria-hidden>
                ✓
              </span>
              <span className="text-muted">{p}</span>
            </li>
          ))}
        </ul>
      </section>

      {/* CTA */}
      <section className="my-16 rounded-3xl border border-borderline bg-gradient-to-br from-surface to-surface-raised p-10 text-center">
        <h2 className="text-2xl font-bold tracking-tight sm:text-3xl">
          Releasing soon? Start now.
        </h2>
        <p className="mx-auto mt-3 max-w-xl text-muted">
          Make an account, upload the track, pick a vibe, and your clips render
          while you carry on with the rest of the release.
        </p>
        <div className="mt-8 flex flex-col items-center gap-3">
          <Link
            href="/login?new=1"
            className="glow-hover-strong brand-gradient inline-block rounded-xl px-8 py-3 font-semibold text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
          >
            Start free
          </Link>
          <Link
            href="/upload"
            className="text-sm text-muted underline underline-offset-4 transition hover:text-foreground"
          >
            Or have us hand-build your first clip
          </Link>
        </div>
      </section>

      <footer className="flex flex-col items-center gap-3 border-t border-borderline py-8 text-center text-xs text-muted">
        <Logo size={26} />
        <p>The video studio built for music releases. · © 2026 ChorusFrame</p>
        <nav className="flex flex-wrap justify-center gap-4">
          <Link href="/examples" className="transition hover:text-foreground">
            Examples
          </Link>
          <Link href="/pricing" className="transition hover:text-foreground">
            Pricing
          </Link>
          <Link href="/legal/terms" className="transition hover:text-foreground">
            Terms
          </Link>
          <Link href="/legal/privacy" className="transition hover:text-foreground">
            Privacy
          </Link>
          <Link href="/legal/copyright" className="transition hover:text-foreground">
            Copyright
          </Link>
        </nav>
        <p>By uploading, you confirm you own the rights to your music and artwork.</p>
      </footer>
    </main>
  );
}
