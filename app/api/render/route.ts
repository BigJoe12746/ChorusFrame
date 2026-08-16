import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

const VALID_FORMATS = ["vertical", "square", "wide"] as const;
/** Keep in step with remotion/vibes.ts — an unknown id renders the default. */
const VALID_VIBES = ["hyperpop", "anime", "dreamy", "cinematic", "reggae", "minimal"] as const;
const MIN_DURATION = 5;
const MAX_DURATION = 60;
/** No song we accept is longer than this, so a start beyond it can only fail. */
const MAX_START = 900;

/**
 * Renders an artist can start per rolling 24h during beta.
 *
 * DAILY_LIMIT counts only jobs that weren't failures: "failed renders never
 * consume credits" is a promise on the marketing page, so a render that
 * produced nothing must not use up the artist's allowance.
 *
 * ABUSE_LIMIT counts every job including failures. It exists purely so a
 * caller who deliberately fails renders can't burn compute forever, and it
 * sits far enough above DAILY_LIMIT that honest use never reaches it.
 */
const DAILY_LIMIT = 5;
const ABUSE_LIMIT = 25;

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

  // Ownership, per-song dedupe, quota, and the insert all happen inside one
  // transaction. Checking in the route and inserting afterwards let several
  // concurrent requests each read "under the limit" and each insert.
  const { data, error } = await supabase.rpc("enqueue_render_job", {
    p_user: user.id,
    p_submission: body.submissionId,
    p_formats: formats,
    p_start: start,
    p_duration: duration,
    p_daily_limit: DAILY_LIMIT,
    p_abuse_limit: ABUSE_LIMIT,
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
      return NextResponse.json(
        {
          error: `That's ${DAILY_LIMIT} renders in 24 hours — the beta limit. Failed renders don't count toward it.`,
        },
        { status: 429 }
      );
    case "abuse":
      return NextResponse.json(
        { error: "Too many render attempts in 24 hours. Try again tomorrow." },
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
