import Link from "next/link";
import SiteHeader from "@/components/SiteHeader";
import UpgradePanel from "@/components/UpgradePanel";
import { FOUNDING, PLANS, getPlan, money } from "@/lib/plans";
import { getSupabaseAdmin, getSupabaseServer } from "@/lib/supabase";

export const dynamic = "force-dynamic";
export const metadata = { title: "Billing — ChorusFrame" };

export default async function BillingPage({ searchParams }: PageProps<"/dashboard/billing">) {
  const upgraded = String((await searchParams)?.upgraded ?? "") === "1";
  const supabase = await getSupabaseServer();
  if (!supabase) return null; // middleware already gates this route

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: profile } = await supabase
    .from("profiles")
    .select("plan, plan_status, plan_period_end, founding_member")
    .eq("id", user?.id ?? "")
    .maybeSingle();

  const plan = getPlan(profile?.plan);
  const isPro = plan.id === "pro";

  let exportsUsed = 0;
  {
    const { data: used } = await supabase.rpc("exports_used_this_month", {
      p_user: user?.id ?? "",
    });
    if (typeof used === "number") exportsUsed = used;
  }

  // Founding seats left — counted in SQL, shown truthfully or not at all
  let foundingLeft: number | null = null;
  const admin = getSupabaseAdmin();
  if (admin) {
    const { data: taken } = await admin.rpc("founding_seats_taken");
    if (typeof taken === "number") foundingLeft = Math.max(0, FOUNDING.seats - taken);
  }

  const renewal = profile?.plan_period_end
    ? new Date(profile.plan_period_end).toLocaleDateString("en-US", {
        month: "long",
        day: "numeric",
        year: "numeric",
      })
    : null;

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
    <main className="mx-auto w-full max-w-3xl flex-1 px-6">

      <section className="py-8">
        <h1 className="text-3xl font-bold tracking-tight">Billing</h1>

        {upgraded ? (
          <p className="mt-4 rounded-xl border border-cyan/40 bg-surface p-4 text-sm">
            Welcome to Pro. Your new limits are live — go make something.
          </p>
        ) : null}

        {/* Current state, plainly */}
        <div className="mt-6 rounded-2xl border border-borderline bg-surface p-6">
          <div className="flex flex-wrap items-baseline justify-between gap-3">
            <div>
              <p className="text-xs uppercase tracking-[0.2em] text-muted">Your plan</p>
              <p className="mt-1 text-2xl font-bold">
                {plan.name}
                {profile?.founding_member ? (
                  <span className="ml-2 align-middle rounded-full border border-cyan/50 px-2 py-0.5 text-xs font-medium text-cyan">
                    Founding member
                  </span>
                ) : null}
              </p>
            </div>
            <p className="text-sm text-muted">
              {exportsUsed} of {plan.exportsPerMonth} exports used this month
            </p>
          </div>

          {isPro && renewal ? (
            <p className="mt-3 text-xs text-muted">
              {profile?.plan_status === "canceled"
                ? `Pro runs until ${renewal}, then you move to Free. Your songs and clips stay.`
                : `Renews ${renewal}. Cancel any time before then from Manage billing.`}
            </p>
          ) : null}

          {profile?.plan_status === "past_due" ? (
            <p className="mt-3 rounded-lg border border-danger/40 bg-surface-raised p-3 text-xs text-danger">
              Your last payment didn&apos;t go through. Update your card in Manage
              billing to keep Pro.
            </p>
          ) : null}
        </div>

        {/* What Pro adds — from the same source the API enforces */}
        {!isPro ? (
          <div className="mt-6 rounded-2xl border border-borderline bg-surface p-6">
            <h2 className="text-lg font-semibold">
              Pro — {money(PLANS.pro.monthly)}/mo
            </h2>
            <ul className="mt-3 grid gap-2 text-sm text-muted sm:grid-cols-2">
              {PLANS.pro.features.map((f) => (
                <li key={f} className="flex items-start gap-2">
                  <span className="mt-0.5 text-cyan" aria-hidden>
                    ✓
                  </span>
                  {f}
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        <div className="mt-6">
          <UpgradePanel
            isPro={isPro}
            monthlyLabel={`Go Pro — ${money(PLANS.pro.monthly)}/mo`}
            annualLabel={`Annual — ${money(PLANS.pro.annual)}/yr`}
            foundingLabel={`Founding year — ${money(FOUNDING.priceCents)}`}
            foundingLeft={foundingLeft}
          />
        </div>

        <p className="mt-8 text-xs text-muted">
          Failed renders never consume an export. Cancelling never deletes your
          songs or clips. Full details in the{" "}
          <Link href="/legal/terms" className="text-cyan underline underline-offset-4">
            terms
          </Link>
          .
        </p>
      </section>
    </main>
    </>
  );
}
