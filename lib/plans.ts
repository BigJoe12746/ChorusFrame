// Plans and entitlements — the single source of truth for what a plan allows.
//
// Prices and limits come from the business plan. Everything that decides what
// an artist can do reads from here, so a limit can never drift between the
// pricing page, the API that enforces it, and the dashboard that reports it.
//
// Two rules from the plan are structural rather than cosmetic, and the code
// has to honour them because they are printed on the marketing page:
//   "You will always know what an export costs"
//   "Failed renders never consume credits"

export type PlanId = "free" | "creator" | "creator_ai" | "teams";

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
  /** Template ids, or "all". */
  templates: "basic" | "all";
  /** Metered credits for expensive generative features, per month. */
  aiCredits: number;
  /**
   * True when `monthly`/`annual` are charged per seat rather than per account.
   * Measured against real render costs, Teams at a flat $19.99 for 1,000
   * exports returns 39% margin; per seat it returns 88%, in line with the
   * other plans. The business plan quotes "$14.99/user/mo annual", so per
   * seat is the intended reading.
   */
  perSeat?: boolean;
  storageGb: number;
  seats: number;
  features: string[];
};

export const PLANS: Record<PlanId, Plan> = {
  free: {
    id: "free",
    name: "Free",
    monthly: 0,
    annual: 0,
    tagline: "Try it on a real release",
    exportsPerMonth: 10,
    formats: ["vertical", "square", "wide"],
    maxClipSeconds: 30,
    templates: "basic",
    aiCredits: 0,
    storageGb: 2,
    seats: 1,
    features: [
      "10 exports a month",
      "1080p, every aspect ratio",
      "Basic templates",
      "Tap-to-sync lyric timing",
      "ChorusFrame end card",
    ],
  },
  creator: {
    id: "creator",
    name: "Creator",
    monthly: 999,
    annual: 7999,
    tagline: "For artists releasing regularly",
    exportsPerMonth: 100,
    formats: ["vertical", "square", "wide"],
    maxClipSeconds: 60,
    templates: "all",
    aiCredits: 0,
    storageGb: 100,
    seats: 1,
    features: [
      "100 exports a month",
      "Every template",
      "Clips up to 60 seconds",
      "No end card",
      "100GB of storage",
    ],
  },
  creator_ai: {
    id: "creator_ai",
    name: "Creator AI",
    monthly: 1699,
    annual: 13999,
    tagline: "For high-frequency creators",
    exportsPerMonth: 300,
    formats: ["vertical", "square", "wide"],
    maxClipSeconds: 60,
    templates: "all",
    aiCredits: 500,
    storageGb: 250,
    seats: 1,
    features: [
      "300 exports a month",
      "Everything in Creator",
      "Automatic lyric alignment",
      "500 AI credits a month",
      "Batch exports",
    ],
  },
  teams: {
    id: "teams",
    name: "Teams",
    monthly: 1999,
    // The plan quotes Teams as "$14.99/user/mo annual" — a monthly-equivalent,
    // not a yearly total. Stored as the yearly figure per seat (14.99 x 12) so
    // it means the same thing as every other plan's `annual`.
    annual: 17988,
    perSeat: true,
    tagline: "For labels and managers",
    exportsPerMonth: 1000,
    formats: ["vertical", "square", "wide"],
    maxClipSeconds: 60,
    templates: "all",
    aiCredits: 1000,
    storageGb: 1000,
    seats: 5,
    features: [
      "1,000 exports a month",
      "Shared brand kits",
      "Pooled AI credits",
      "Approvals and admin controls",
      "Priced per seat, 5 seat minimum",
    ],
  },
};

/**
 * Founding-year offer: the plan promises the first 1,000 paying customers an
 * annual Creator plan at $59.99, renewing at the standard rate with notice.
 */
export const FOUNDING = {
  priceCents: 5999,
  seats: 1000,
  planId: "creator" as PlanId,
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
      reason: `${plan.name} covers clips up to ${plan.maxClipSeconds} seconds. Upgrade for longer cuts.`,
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
