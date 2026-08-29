import type { Metadata } from "next";
import Link from "next/link";
import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";

export const metadata: Metadata = {
  title: "Examples — ChorusFrame",
  description:
    "The same demo song rendered through six ChorusFrame templates — real output from the real pipeline, nothing staged.",
};

/*
 * Proof, not adjectives. Every clip here came out of the exact render
 * pipeline artists use — same demo song, six of the ten templates — so what
 * a visitor sees is what their own song gets.
 */
const EXAMPLES = [
  { id: "hyperpop", label: "Hyperpop", blurb: "Candy colours, heavy caps, hard bass pump" },
  { id: "anime", label: "Dark anime", blurb: "Deep blacks, blood red, dramatic and still" },
  { id: "minimal", label: "Minimal", blurb: "Monochrome, thin type, almost no motion" },
  { id: "poster", label: "Poster", blurb: "The cover fills the screen, words on top" },
  { id: "retro", label: "Retro", blurb: "Warm, faded, VHS-ish" },
  { id: "neon", label: "Neon", blurb: "Black and glow, club energy" },
];

export default function ExamplesPage() {
  return (
    <>
    <SiteHeader />
    <main className="mx-auto w-full max-w-5xl flex-1 px-6">
      <section className="py-16 text-center sm:py-20">
        <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">
          One song. <span className="brand-text">Six directions.</span>
        </h1>
        <p className="mx-auto mt-5 max-w-2xl text-lg text-muted">
          The same demo track rendered through six of our ten templates, by the
          exact pipeline your songs go through. Tap any clip for sound — the
          bars move to the music, the words land on the beat.
        </p>
      </section>

      <section className="grid grid-cols-2 gap-4 pb-12 sm:grid-cols-3 sm:gap-6">
        {EXAMPLES.map((e) => (
          <figure key={e.id} className="flex flex-col gap-2">
            <video
              src={`/demo/clips/${e.id}.mp4`}
              controls
              loop
              playsInline
              preload="metadata"
              className="w-full rounded-xl border border-borderline bg-surface"
              style={{ aspectRatio: "9 / 16" }}
            />
            <figcaption>
              <p className="text-sm font-semibold">{e.label}</p>
              <p className="text-xs text-muted">{e.blurb}</p>
            </figcaption>
          </figure>
        ))}
      </section>

      <section className="mb-16 rounded-3xl border border-borderline bg-gradient-to-br from-surface to-surface-raised p-10 text-center">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
          Now with your song.
        </h2>
        <p className="mx-auto mt-3 max-w-xl text-muted">
          Upload the track, pick the hook, choose a direction — your clips
          render in every format while you carry on with the release.
        </p>
        <div className="mt-8 flex flex-col items-center gap-3">
          <Link
            href="/login?new=1"
            className="glow-hover-strong brand-gradient inline-block rounded-full px-8 py-3 font-semibold text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
          >
            Start free — upload a song
          </Link>
          <Link
            href="/pricing"
            className="text-sm text-muted underline underline-offset-4 transition hover:text-foreground"
          >
            See pricing
          </Link>
        </div>
      </section>

      <SiteFooter />
    </main>
    </>
  );
}
