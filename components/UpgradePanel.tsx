"use client";

import { useState } from "react";

/**
 * The buy buttons — and the honest state when checkout isn't live.
 *
 * Both talk to APIs that hold the truth server-side; this component never
 * decides prices or eligibility, it only renders what it's told and relays
 * refusals in the words the API gave.
 */
export default function UpgradePanel({
  monthlyLabel,
  annualLabel,
  foundingLabel,
  foundingLeft,
  isPro,
}: {
  monthlyLabel: string;
  annualLabel: string;
  foundingLabel: string;
  /** Seats remaining, or null when the count is unavailable. */
  foundingLeft: number | null;
  isPro: boolean;
}) {
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState("");

  async function go(path: string, body?: object) {
    setBusy(path + JSON.stringify(body ?? {}));
    setNotice("");
    try {
      const res = await fetch(path, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: body ? JSON.stringify(body) : undefined,
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Something went wrong");
      if (data.url) window.location.assign(data.url);
    } catch (e) {
      setNotice(e instanceof Error ? e.message : "Something went wrong");
    } finally {
      setBusy(null);
    }
  }

  if (isPro) {
    return (
      <div className="flex flex-col gap-2">
        <button
          onClick={() => go("/api/billing/portal")}
          disabled={busy !== null}
          className="self-start rounded-full border border-borderline px-5 py-2.5 text-sm font-semibold transition hover:border-cyan disabled:opacity-60 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
        >
          {busy ? "Opening…" : "Manage billing"}
        </button>
        <p className="text-xs text-muted">
          Card, invoices, switching monthly/annual, and cancelling all live here.
        </p>
        {notice ? <p className="text-xs text-danger">{notice}</p> : null}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => go("/api/billing/checkout", { interval: "monthly" })}
          disabled={busy !== null}
          className="glow-hover-strong brand-gradient rounded-full px-5 py-2.5 text-sm font-semibold text-white transition hover:opacity-90 disabled:opacity-60 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
        >
          {monthlyLabel}
        </button>
        <button
          onClick={() => go("/api/billing/checkout", { interval: "annual" })}
          disabled={busy !== null}
          className="glow-hover rounded-full border border-borderline px-5 py-2.5 text-sm font-semibold transition hover:border-cyan disabled:opacity-60 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
        >
          {annualLabel}
        </button>
      </div>

      {foundingLeft === null || foundingLeft > 0 ? (
        <button
          onClick={() => go("/api/billing/checkout", { interval: "founding" })}
          disabled={busy !== null}
          className="glow-hover self-start rounded-full border border-cyan/50 px-5 py-2.5 text-sm font-semibold text-cyan transition hover:border-cyan disabled:opacity-60 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
        >
          {foundingLabel}
          {foundingLeft !== null ? (
            <span className="ml-2 font-normal text-muted">
              {foundingLeft.toLocaleString()} left
            </span>
          ) : null}
        </button>
      ) : null}

      {notice ? (
        <p className="max-w-md rounded-lg border border-borderline bg-surface p-3 text-xs text-muted">
          {notice}
        </p>
      ) : null}
    </div>
  );
}
