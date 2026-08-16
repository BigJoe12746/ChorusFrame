import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

const VALID_FORMATS = ["vertical", "square", "wide"] as const;
const MIN_DURATION = 5;
const MAX_DURATION = 60;

/**
 * Renders an artist can start per rolling 24h during beta.
 * Failed jobs are excluded from this count on purpose — "failed renders never
 * consume credits" is a promise on the marketing page, so a render that
 * doesn't produce a clip must not use up the artist's allowance either.
 */
const DAILY_LIMIT = 5;

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

  const formats: string[] = Array.isArray(body.formats) && body.formats.length
    ? body.formats
    : ["vertical"];
  if (formats.some((f) => !VALID_FORMATS.includes(f as (typeof VALID_FORMATS)[number]))) {
    return NextResponse.json({ error: "Unknown format requested" }, { status: 400 });
  }

  const start = Number(body.clipStartSeconds ?? 0);
  const duration = Number(body.durationSeconds ?? 15);
  if (!Number.isFinite(start) || start < 0) {
    return NextResponse.json({ error: "Invalid clip start" }, { status: 400 });
  }
  if (!Number.isFinite(duration) || duration < MIN_DURATION || duration > MAX_DURATION) {
    return NextResponse.json(
      { error: `Clip length must be between ${MIN_DURATION} and ${MAX_DURATION} seconds` },
      { status: 400 }
    );
  }

  // Ownership: the artist may only render their own upload. Checked against the
  // row's user_id rather than trusting anything in the request body.
  const { data: sub, error: subErr } = await supabase
    .from("submissions")
    .select("id, user_id")
    .eq("id", body.submissionId)
    .maybeSingle();
  if (subErr) {
    return NextResponse.json({ error: "Could not load that song" }, { status: 500 });
  }
  if (!sub || sub.user_id !== user.id) {
    // Same response whether it's missing or someone else's — don't confirm existence
    return NextResponse.json({ error: "Song not found" }, { status: 404 });
  }

  // One active job per song, so double-clicking doesn't queue duplicates
  const { data: active } = await supabase
    .from("render_jobs")
    .select("id")
    .eq("submission_id", sub.id)
    .in("status", ["queued", "rendering"])
    .limit(1);
  if (active?.length) {
    return NextResponse.json({ ok: true, id: active[0].id, alreadyQueued: true });
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error: countErr } = await supabase
    .from("render_jobs")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id)
    .neq("status", "failed")
    .gte("created_at", since);
  if (countErr) {
    return NextResponse.json({ error: "Could not check your render quota" }, { status: 500 });
  }
  if ((count ?? 0) >= DAILY_LIMIT) {
    return NextResponse.json(
      {
        error: `That's ${DAILY_LIMIT} renders in 24 hours — the beta limit. Failed renders don't count toward it.`,
      },
      { status: 429 }
    );
  }

  const { data: job, error: insErr } = await supabase
    .from("render_jobs")
    .insert({
      submission_id: sub.id,
      user_id: user.id,
      formats,
      clip_start_seconds: start,
      duration_seconds: duration,
    })
    .select("id")
    .single();

  if (insErr || !job) {
    console.error("[render] enqueue failed:", insErr);
    return NextResponse.json({ error: "Could not start the render" }, { status: 500 });
  }

  return NextResponse.json({ ok: true, id: job.id });
}
