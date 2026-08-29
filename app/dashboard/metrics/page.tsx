import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import SiteHeader from "@/components/SiteHeader";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Metrics — ChorusFrame",
  robots: { index: false, follow: false },
};

/**
 * The scorecard, computed from real events.
 *
 * Admin-only, and gated on an env var rather than a database role: there is
 * exactly one operator today, and inventing a permissions system for one
 * person would be more surface than value. Set ADMIN_USER_IDS to a
 * comma-separated list of account ids; with it unset the page 404s for
 * everyone, which is the right default for a page that exists to expose
 * business numbers.
 */
function isAdmin(userId: string | undefined | null) {
  const allowed = (process.env.ADMIN_USER_IDS ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return Boolean(userId && allowed.includes(userId));
}

const LABELS: Record<string, { label: string; suffix?: string; target?: string }> = {
  visitors: { label: "Visitors" },
  signups: { label: "Signups" },
  uploads: { label: "Artists who uploaded" },
  renders_started: { label: "Renders started" },
  renders_done: { label: "Renders finished" },
  renders_failed: { label: "Renders failed" },
  upgrades: { label: "Upgrades" },
  cancellations: { label: "Cancellations" },
  upload_rate: { label: "Signup → upload", suffix: "%" },
  activation_rate: { label: "Signup → first export", suffix: "%", target: "45% healthy" },
  export_success_rate: { label: "Export success", suffix: "%", target: "98% healthy" },
  conversion_rate: { label: "Signup → paid", suffix: "%", target: "4–7% healthy" },
  week4_retention: { label: "Week-4 retention", suffix: "%", target: "25% healthy" },
  median_minutes_to_first_clip: {
    label: "Median time to first clip",
    suffix: " min",
    target: "under 10 min",
  },
};

const COUNTS = [
  "visitors",
  "signups",
  "uploads",
  "renders_started",
  "renders_done",
  "renders_failed",
  "upgrades",
  "cancellations",
];

const RATES = [
  "upload_rate",
  "activation_rate",
  "export_success_rate",
  "conversion_rate",
  "week4_retention",
  "median_minutes_to_first_clip",
];

/** Undefined metrics come back as null and must read as "no data", not zero. */
const show = (v: number | null | undefined) =>
  v === null || v === undefined ? "—" : Number(v).toLocaleString();

export default async function MetricsPage({ searchParams }: PageProps<"/dashboard/metrics">) {
  const user = await getCurrentUser();
  if (!isAdmin(user?.id)) notFound();

  const days = Math.min(365, Math.max(1, Number((await searchParams)?.days ?? 30) || 30));
  const admin = getSupabaseAdmin();

  let rows: { metric: string; value: number; detail: string }[] = [];
  let error: string | null = null;
  if (admin) {
    const { data, error: rpcErr } = await admin.rpc("funnel_metrics", { p_days: days });
    if (rpcErr) error = rpcErr.message;
    else rows = (data ?? []) as typeof rows;
  }

  const by = new Map(rows.map((r) => [r.metric, r]));

  return (
    <>
      <SiteHeader>
        <Link
          href="/dashboard"
          className="rounded-lg text-sm text-muted transition hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan"
        >
          ← Back to your songs
        </Link>
      </SiteHeader>

      <main className="mx-auto w-full max-w-4xl flex-1 px-6">
        <section className="py-10">
          <h1 className="text-3xl font-bold tracking-tight">Metrics</h1>
          <p className="mt-2 text-sm text-muted">
            The last {days} days, from first-party events. Nothing here leaves
            our own database.
          </p>
          <nav className="mt-4 flex gap-2">
            {[7, 30, 90].map((d) => (
              <Link
                key={d}
                href={`/dashboard/metrics?days=${d}`}
                className={`rounded-full border px-3 py-1 text-xs transition ${
                  d === days
                    ? "border-cyan text-foreground"
                    : "border-borderline text-muted hover:border-cyan hover:text-foreground"
                }`}
              >
                {d} days
              </Link>
            ))}
          </nav>
        </section>

        {error ? (
          <p className="rounded-2xl border border-borderline bg-surface p-4 text-sm text-danger">
            Could not read metrics: {error}
            {/removed|does not exist|schema cache/i.test(error)
              ? " — apply supabase/010_events.sql."
              : ""}
          </p>
        ) : null}

        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {COUNTS.map((k) => {
            const r = by.get(k);
            const meta = LABELS[k];
            return (
              <div key={k} className="rounded-2xl border border-borderline bg-surface p-4">
                <p className="text-2xl font-semibold tabular-nums">{show(r?.value)}</p>
                <p className="mt-1 text-xs text-muted">{meta.label}</p>
              </div>
            );
          })}
        </section>

        <section className="mt-4 flex flex-col gap-3 pb-16">
          {RATES.map((k) => {
            const r = by.get(k);
            const meta = LABELS[k];
            return (
              <div
                key={k}
                className="flex flex-wrap items-baseline justify-between gap-2 rounded-2xl border border-borderline bg-surface p-4"
              >
                <div>
                  <p className="text-sm font-medium">{meta.label}</p>
                  <p className="text-xs text-muted">{r?.detail ?? "no data yet"}</p>
                </div>
                <div className="text-right">
                  <p className="text-2xl font-semibold tabular-nums">
                    {show(r?.value)}
                    {r?.value === null || r?.value === undefined ? null : (
                      <span className="text-sm text-muted">{meta.suffix ?? ""}</span>
                    )}
                  </p>
                  {meta.target ? <p className="text-[11px] text-muted">{meta.target}</p> : null}
                </div>
              </div>
            );
          })}
        </section>
      </main>
    </>
  );
}
