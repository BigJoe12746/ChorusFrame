// Plans and entitlements — the single source of truth for what a plan allows.
//
// Two plans, deliberately. The business plan sketched four (Free, Creator,
// Creator AI, Teams), but three of them sold things that do not exist yet:
// 4K, AI credits, translation, approvals. Advertising those before they are
// built is how a product ends up owing its customers features. Everything
// listed here is something the product does today; tiers come back when the
// features behind them are real.
//
// Two rules from the plan are structural rather than cosmetic, because they
// are printed on the marketing page:
//   "You will always know what an export costs"
//   "Failed renders never consume credits"

export type PlanId = "free" | "pro";

export type Plan = {
  id: PlanId;
  name: string;
  /** Cents, billed monthly. */
  monthly: number;
  /** Cents, billed once a year. */
  annual: number;
  tagline: string;
  /** Renders an artist may START per calendar month. Failures don't count. */
  exportsPerMonth: number;
  /** Formats available per render. */
  formats: ("vertical" | "square" | "wide")[];
  maxClipSeconds: number;
  /** How many of the ten visual directions are available. */
  templates: number;
  /** Which vibes those are — enforced by the render API, not just printed. */
  templateIds: string[];
  /** Saved colours and type applied to every render. */
  brandKit: boolean;
  /** Whether the ChorusFrame end card is appended. */
  endCard: boolean;
  /** Whether the corner watermark renders on clips. */
  watermark: boolean;
  storageGb: number;
  features: string[];
};

export const PLANS: Record<PlanId, Plan> = {
  free: {
    id: "free",
    name: "Free",
    monthly: 0,
    annual: 0,
    tagline: "Enough to put a real release out",
    exportsPerMonth: 5,
    // Every format stays on Free on purpose: "one upload, every format" is the
    // whole pitch, and gating it would undercut the thing worth trying.
    formats: ["vertical", "square", "wide"],
    maxClipSeconds: 15,
    templates: 3,
    // One flashy, one clean, one serious — enough range to hear the pitch.
    templateIds: ["hyperpop", "minimal", "cinematic"],
    brandKit: false,
    endCard: true,
    watermark: true,
    storageGb: 2,
    features: [
      "5 exports a month",
      "9:16, 1:1 and 16:9 from one upload",
      "Clips up to 15 seconds",
      "3 templates: Hyperpop, Minimal, Cinematic",
      "Hook detection and tap-to-sync lyrics",
      "ChorusFrame watermark and end card",
    ],
  },
  pro: {
    id: "pro",
    name: "Pro",
    monthly: 1000,
    // ~17% off, the usual shape for an annual plan
    annual: 9900,
    tagline: "For artists releasing regularly",
    exportsPerMonth: 100,
    formats: ["vertical", "square", "wide"],
    maxClipSeconds: 60,
    templates: 10,
    templateIds: [
      "hyperpop", "anime", "dreamy", "cinematic", "reggae",
      "minimal", "poster", "typographic", "retro", "neon",
    ],
    brandKit: true,
    endCard: false,
    watermark: false,
    storageGb: 100,
    features: [
      "100 exports a month",
      "Clips up to 60 seconds",
      "All 10 templates",
      "Your brand kit on every render",
      "No watermark, no end card",
    ],
  },
};

/**
 * Founding offer: the first 1,000 paying customers get Pro at this price and
 * KEEP it at renewal for as long as they stay subscribed. "Your price never
 * goes up" is the strongest loyalty promise a small brand can make, and it
 * matches what supabase/006_billing.sql records. (Decided August 2026 —
 * previously this comment and the schema contradicted each other.)
 */
export const FOUNDING = {
  priceCents: 5999,
  seats: 1000,
  planId: "pro" as PlanId,
};

export const DEFAULT_PLAN: PlanId = "free";

export function getPlan(id: string | null | undefined): Plan {
  return PLANS[(id ?? "") as PlanId] ?? PLANS[DEFAULT_PLAN];
}

export const money = (cents: number) =>
  cents === 0 ? "Free" : `$${(cents / 100).toFixed(2).replace(/\.00$/, "")}`;

/** Everything the UI needs to tell an artist what a render will cost them. */
export type Entitlement = {
  plan: Plan;
  usedThisMonth: number;
  remaining: number;
  allowed: boolean;
  /** Why a render was refused, in words an artist can act on. */
  reason?: string;
};

export function checkEntitlement({
  planId,
  usedThisMonth,
  clipSeconds,
  formats,
}: {
  planId: string | null | undefined;
  usedThisMonth: number;
  clipSeconds: number;
  formats: string[];
}): Entitlement {
  const plan = getPlan(planId);
  const remaining = Math.max(0, plan.exportsPerMonth - usedThisMonth);
  const base = { plan, usedThisMonth, remaining };

  if (clipSeconds > plan.maxClipSeconds) {
    return {
      ...base,
      allowed: false,
      reason: `${plan.name} covers clips up to ${plan.maxClipSeconds} seconds. Pro goes to ${PLANS.pro.maxClipSeconds}.`,
    };
  }
  const unavailable = formats.filter((f) => !plan.formats.includes(f as Plan["formats"][number]));
  if (unavailable.length) {
    return {
      ...base,
      allowed: false,
      reason: `${plan.name} doesn't include ${unavailable.join(", ")}.`,
    };
  }
  if (remaining <= 0) {
    return {
      ...base,
      allowed: false,
      reason: `You've used all ${plan.exportsPerMonth} exports this month. Renders that failed don't count.`,
    };
  }
  return { ...base, allowed: true };
}
