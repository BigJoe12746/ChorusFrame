import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";
import { MAX_DURATION, MAX_START, MIN_DURATION } from "@/lib/clip-limits";
import { checkEntitlement } from "@/lib/plans";

export const runtime = "nodejs";

const VALID_FORMATS = ["vertical", "square", "wide", "canvas"] as const;
/** Keep in step with remotion/vibes.ts — an unknown id renders the default. */
const VALID_VIBES = [
  "hyperpop",
  "anime",
  "dreamy",
  "cinematic",
  "reggae",
  "minimal",
  "poster",
  "typographic",
  "retro",
  "neon",
] as const;

/**
 * What an artist may render comes from their plan (lib/plans.ts), counted per
 * calendar month, with failures excluded — "failed renders never consume
 * credits" is a promise on the marketing page.
 *
 * ABUSE_LIMIT is separate and counts EVERY job including failures. It exists
 * only so a caller who deliberately fails renders can't burn compute forever,
 * and sits far above any plan's monthly allowance so honest use never meets
 * it. Keeping the two apart is what lets the promise stay true.
 */
const ABUSE_LIMIT_PER_DAY = 40;

export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ error: "Sign in to render clips" }, { status: 401 });
  }

  const supabase = getSupabaseAdmin();
  if (!supabase) {
    return NextResponse.json({ error: "Rendering isn't configured" }, { status: 503 });
  }

  const body = await req.json().catch(() => null);
  if (!body || typeof body.submissionId !== "string") {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }

  // Dedupe and cap: a request asking for the same format ten times would
  // otherwise multiply the work for a single job.
  const requested: unknown = body.formats;
  const formats = [
    ...new Set(Array.isArray(requested) && requested.length ? requested : ["vertical"]),
  ];
  if (
    formats.length > VALID_FORMATS.length ||
    formats.some((f) => !VALID_FORMATS.includes(f as (typeof VALID_FORMATS)[number]))
  ) {
    return NextResponse.json({ error: "Unknown format requested" }, { status: 400 });
  }

  const start = Number(body.clipStartSeconds ?? 0);
  const duration = Number(body.durationSeconds ?? 15);
  if (!Number.isFinite(start) || start < 0 || start > MAX_START) {
    return NextResponse.json({ error: "Invalid clip start" }, { status: 400 });
  }
  if (!Number.isFinite(duration) || duration < MIN_DURATION || duration > MAX_DURATION) {
    return NextResponse.json(
      { error: `Clip length must be between ${MIN_DURATION} and ${MAX_DURATION} seconds` },
      { status: 400 }
    );
  }

  const vibe = typeof body.vibe === "string" ? body.vibe : null;
  if (vibe && !VALID_VIBES.includes(vibe as (typeof VALID_VIBES)[number])) {
    return NextResponse.json({ error: "Unknown vibe" }, { status: 400 });
  }

  // What this artist's plan allows. Checked before the enqueue so the refusal
  // names the actual reason — clip too long, format not included, allowance
  // spent — rather than a generic "quota".
  const { data: profile } = await supabase
    .from("profiles")
    .select("plan")
    .eq("id", user.id)
    .maybeSingle();
  const { data: usedRaw } = await supabase.rpc("exports_used_this_month", { p_user: user.id });
  const usedThisMonth = Number(usedRaw ?? 0);

  const entitlement = checkEntitlement({
    planId: profile?.plan,
    usedThisMonth,
    clipSeconds: duration,
    formats,
  });
  if (!entitlement.allowed) {
    return NextResponse.json(
      { error: entitlement.reason, plan: entitlement.plan.id, upgrade: true },
      { status: 402 }
    );
  }

  // Templates are sold by plan; the picker shows locked vibes but the API is
  // what actually holds the line.
  if (vibe && !entitlement.plan.templateIds.includes(vibe)) {
    return NextResponse.json(
      {
        error: `That template is on Pro. ${entitlement.plan.name} includes ${entitlement.plan.templateIds.join(", ")}.`,
        plan: entitlement.plan.id,
        upgrade: true,
      },
      { status: 402 }
    );
  }

  // Ownership, per-song dedupe, the abuse ceiling and the insert all happen
  // inside one transaction. Checking in the route and inserting afterwards let
  // several concurrent requests each read "under the limit" and each insert.
  const { data, error } = await supabase.rpc("enqueue_render_job", {
    p_user: user.id,
    p_submission: body.submissionId,
    p_formats: formats,
    p_start: start,
    p_duration: duration,
    // The plan allowance was just checked above; pass it through so the
    // transaction re-checks it atomically rather than trusting our read.
    p_daily_limit: entitlement.remaining,
    p_abuse_limit: ABUSE_LIMIT_PER_DAY,
    p_vibe: vibe,
  });

  if (error) {
    console.error("[render] enqueue failed:", error);
    return NextResponse.json({ error: "Could not start the render" }, { status: 500 });
  }

  const row = Array.isArray(data) ? data[0] : data;
  switch (row?.outcome) {
    case "created":
      return NextResponse.json({ ok: true, id: row.job_id });
    case "already_queued":
      return NextResponse.json({ ok: true, id: row.job_id, alreadyQueued: true });
    case "quota":
      // The transaction re-checked and disagreed with our read — a concurrent
      // render used the last of the allowance between the two.
      return NextResponse.json(
        {
          error: `You've used all ${entitlement.plan.exportsPerMonth} exports this month. Renders that failed don't count.`,
          plan: entitlement.plan.id,
          upgrade: true,
        },
        { status: 402 }
      );
    case "abuse":
      return NextResponse.json(
        { error: "Too many render attempts today. Try again tomorrow." },
        { status: 429 }
      );
    case "not_found":
      // Same response whether it's missing or someone else's — don't confirm existence
      return NextResponse.json({ error: "Song not found" }, { status: 404 });
    default:
      console.error("[render] unexpected enqueue outcome:", row);
      return NextResponse.json({ error: "Could not start the render" }, { status: 500 });
  }
}
