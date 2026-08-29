import Link from "next/link";
import Logo from "@/components/Logo";

export default function NotFound() {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col px-6">
      <header className="py-6">
        <Link
          href="/"
          className="inline-flex rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan"
        >
          <Logo size={26} />
        </Link>
      </header>
      <section className="flex flex-1 items-center pb-24">
        <div className="w-full rounded-2xl border border-borderline bg-surface p-10 text-center">
          <p className="text-4xl" aria-hidden>
            🎬
          </p>
          <h1 className="mt-4 text-xl font-semibold">Nothing plays here</h1>
          <p className="mx-auto mt-2 max-w-sm text-sm text-muted">
            This page doesn&apos;t exist — or the clips that lived here were
            taken down by the artist.
          </p>
          <div className="mt-6 flex flex-col items-center gap-3">
            <Link
              href="/"
              className="glow-hover-strong brand-gradient rounded-full px-6 py-3 text-sm font-semibold text-white transition hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
            >
              Back to ChorusFrame
            </Link>
            <Link
              href="/login?new=1"
              className="text-sm text-cyan underline underline-offset-4 transition hover:text-foreground"
            >
              Make clips for your own song
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
}
