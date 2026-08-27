import type { Metadata } from "next";
import PricingCompare from "@/components/PricingCompare";
import Link from "next/link";
import Logo from "@/components/Logo";
import NavAuth from "@/components/NavAuth";
import { FOUNDING, PLANS, money } from "@/lib/plans";

export const metadata: Metadata = {
  title: "Pricing — ChorusFrame",
  description:
    "A free plan that ships real clips, and Pro at $10 a month. No surprises about what an export costs.",
};

const ORDER = ["free", "pro"] as const;

export default function PricingPage() {
  return (
    <main className="mx-auto w-full max-w-5xl flex-1 px-6">
      <header className="flex items-center justify-between py-6">
        <Link href="/" className="rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan">
          <Logo />
        </Link>
        <NavAuth />
      </header>

      <section className="py-12 text-center sm:py-16">
        <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">
          Pricing that doesn&apos;t{" "}
          <span className="brand-text">surprise you</span>
        </h1>
        <p className="mx-auto mt-5 max-w-2xl text-lg text-muted">
          Start on Free — five exports a month, every format, no card. Move to
          Pro when you&apos;re releasing regularly.
        </p>
      </section>

      <section className="grid gap-4 pb-8 mx-auto max-w-3xl sm:grid-cols-2">
        {ORDER.map((id) => {
          const p = PLANS[id];
          const featured = id === "pro";
          return (
            <div
              key={id}
              className={`flex flex-col rounded-2xl border p-6 ${
                featured
                  ? "border-cyan bg-surface-raised"
                  : "border-borderline bg-surface"
              }`}
            >
              {featured ? (
                <p className="mb-2 text-[11px] font-semibold uppercase tracking-[0.2em] text-cyan">
                  Most artists
                </p>
              ) : null}
              <h2 className="text-lg font-semibold">{p.name}</h2>
              <p className="mt-1 text-xs text-muted">{p.tagline}</p>

              <p className="mt-4">
                <span className="text-3xl font-bold">{money(p.monthly)}</span>
                {p.monthly > 0 ? (
                  <span className="text-sm text-muted">/mo</span>
                ) : null}
              </p>
              {p.annual > 0 ? (
                <p className="mt-1 text-xs text-muted">
                  or {money(p.annual)}/year — {money(Math.round(p.annual / 12))}/mo
                </p>
              ) : null}

              <ul className="mt-5 flex flex-col gap-2 text-sm text-muted">
                {p.features.map((f) => (
                  <li key={f} className="flex gap-2">
                    <span aria-hidden className="text-cyan">
                      ✓
                    </span>
                    <span>{f}</span>
                  </li>
                ))}
              </ul>

              <Link
                href={p.monthly === 0 ? "/login?new=1" : "/dashboard/billing"}
                className={`mt-6 rounded-xl px-4 py-2.5 text-center text-sm font-semibold transition ${
                  featured
                    ? "glow-hover-strong brand-gradient text-white hover:opacity-90"
                    : "glow-hover border border-borderline text-muted hover:border-cyan hover:text-foreground"
                }`}
              >
                {p.monthly === 0 ? "Start on Free" : "Go Pro"}
              </Link>
            </div>
          );
        })}
      </section>

      {/* Founding offer, straight from the plan */}
      <section className="mb-12 rounded-2xl border border-borderline bg-gradient-to-br from-surface to-surface-raised p-8 text-center">
        <h2 className="text-2xl font-bold tracking-tight sm:text-3xl">Founding year</h2>
        <p className="mx-auto mt-3 max-w-xl text-muted">
          The first {FOUNDING.seats.toLocaleString()} paying artists get a year
          of {PLANS[FOUNDING.planId].name} for <span className="text-foreground">{money(FOUNDING.priceCents)}</span> —
          about {money(Math.round(FOUNDING.priceCents / 12))} a month. And founding
          members <span className="text-foreground">keep that price at renewal</span>,
          for as long as they stay subscribed. Your price never goes up.
        </p>
      </section>

      <PricingCompare />

      {/* The promises, restated where they cost us something */}
      <section className="pb-16">
        <h2 className="text-center text-2xl font-bold tracking-tight sm:text-3xl">
          What we promise about money
        </h2>
        <ul className="mx-auto mt-8 grid max-w-3xl gap-3 sm:grid-cols-2">
          {[
            "You always know what an export costs before you run it.",
            "Failed renders never consume an export — they're free, every time.",
            "Your export count resets in full every month.",
            "We meter only what genuinely costs us; editing and rendering stay generous.",
            "Cancel whenever. Your projects aren't deleted out from under you.",
            "Annual and founding plans: full refund within 14 days, pro-rated for use.",
            "Price changes come with notice, never a silent renewal.",
          ].map((t) => (
            <li
              key={t}
              className="flex items-start gap-3 rounded-xl border border-borderline bg-surface p-4 text-sm"
            >
              <span aria-hidden className="mt-0.5 text-cyan">
                ✓
              </span>
              <span className="text-muted">{t}</span>
            </li>
          ))}
        </ul>
      </section>

      <section className="pb-16">
        <h2 className="text-center text-2xl font-bold tracking-tight sm:text-3xl">
          Questions artists actually ask
        </h2>
        <div className="mx-auto mt-8 flex max-w-3xl flex-col gap-3">
          {[
            {
              q: "Who owns the clips?",
              a: "You do. Your music, your artwork, your exports — ChorusFrame claims no rights over anything you upload or render. Free clips carry a small watermark and end card; Pro clips carry neither.",
            },
            {
              q: "What counts as an export?",
              a: "Starting one render of one song, in every format at once, counts as one export. If a render fails, it doesn't count — that's a promise, enforced in the database.",
            },
            {
              q: "Is there a watermark on the Free plan?",
              a: "Yes — a small corner mark and a 2.6-second end card. Pro removes both.",
            },
            {
              q: "What if I cancel?",
              a: "You keep access until the end of what you've paid for, and your songs and clips stay in your library on the Free plan's limits. Nothing is deleted out from under you.",
            },
            {
              q: "Refunds?",
              a: "Monthly plans cancel any time and simply don't renew. Annual and founding plans: full refund within 14 days, pro-rated for exports already used. The details live in the Terms.",
            },
          ].map((f) => (
            <div key={f.q} className="rounded-xl border border-borderline bg-surface p-5">
              <h3 className="text-sm font-semibold">{f.q}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-muted">{f.a}</p>
            </div>
          ))}
        </div>
      </section>

      <footer className="flex flex-wrap justify-center gap-4 border-t border-borderline py-8 text-center text-xs text-muted">
        <Link href="/legal/terms">Terms</Link>
        <Link href="/legal/privacy">Privacy</Link>
        <Link href="/legal/copyright">Copyright</Link>
      </footer>
    </main>
  );
}
