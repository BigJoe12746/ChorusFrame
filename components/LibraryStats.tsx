import { getPlan, type Plan } from "@/lib/plans";

/**
 * What an artist has, and what they have left.
 *
 * The pricing page promises "you always know what an export costs before you
 * run it", which was untrue while nothing showed the month's usage — the
 * database counted it and no screen ever said so.
 */
export default function LibraryStats({
  plan,
  exportsUsed,
  songs,
  clips,
}: {
  plan: Plan;
  exportsUsed: number;
  songs: number;
  clips: number;
}) {
  const remaining = Math.max(0, plan.exportsPerMonth - exportsUsed);
  const pct = Math.min(100, (exportsUsed / plan.exportsPerMonth) * 100);
  const low = remaining <= Math.max(1, Math.round(plan.exportsPerMonth * 0.2));

  const Stat = ({ label, value }: { label: string; value: string }) => (
    <div>
      <p className="text-2xl font-bold tracking-tight">{value}</p>
      <p className="text-xs text-muted">{label}</p>
    </div>
  );

  return (
    <div className="rounded-2xl border border-borderline bg-surface p-5">
      <div className="flex flex-wrap items-start justify-between gap-6">
        <div className="flex flex-wrap gap-8">
          <Stat label={songs === 1 ? "song" : "songs"} value={String(songs)} />
          <Stat label={clips === 1 ? "clip made" : "clips made"} value={String(clips)} />
          <Stat
            label="exports left this month"
            value={`${remaining}`}
          />
        </div>

        <div className="min-w-[12rem] flex-1">
          <div className="flex items-baseline justify-between text-xs">
            <span className="font-medium">{plan.name} plan</span>
            <span className="text-muted">
              {exportsUsed} of {plan.exportsPerMonth} used
            </span>
          </div>
          <div
            role="progressbar"
            aria-valuenow={exportsUsed}
            aria-valuemin={0}
            aria-valuemax={plan.exportsPerMonth}
            aria-label="Exports used this month"
            className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-surface-raised"
          >
            <div
              className={`h-full rounded-full ${low ? "bg-danger" : "brand-gradient"}`}
              style={{ width: `${pct}%` }}
            />
          </div>
          {/* Restating the promise where it costs us something */}
          <p className="mt-2 text-[11px] text-muted">
            Renders that fail don&apos;t count. Resets on the 1st.
          </p>
        </div>
      </div>
    </div>
  );
}
