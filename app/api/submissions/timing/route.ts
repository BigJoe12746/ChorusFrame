import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

const MAX_LINES = 200;

type Line = { text: string; start: number; end: number };

/**
 * Save lyric timings the artist tapped out by hand.
 *
 * Stored the same shape a transcriber would produce — song-absolute seconds —
 * so the render pipeline treats them identically. Marked `manual` rather than
 * `estimated`, which is what stops them being discarded and recomputed: an
 * artist who tapped along to their own song knows better than any model.
 */
export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Sign in first" }, { status: 401 });

  const supabase = getSupabaseAdmin();
  if (!supabase) return NextResponse.json({ error: "Not configured" }, { status: 503 });

  const body = await req.json().catch(() => null);
  if (!body || typeof body.submissionId !== "string" || !Array.isArray(body.timings)) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
  if (body.timings.length > MAX_LINES) {
    return NextResponse.json({ error: "Too many lines" }, { status: 400 });
  }

  // Sanitise: every entry must be finite, ordered, and non-zero length, or the
  // composition will silently drop the line from every clip.
  const timings: Line[] = [];
  let prevEnd = 0;
  for (const raw of body.timings) {
    const text = String(raw?.text ?? "").slice(0, 300).trim();
    const start = Number(raw?.start);
    const end = Number(raw?.end);
    if (!text || !Number.isFinite(start) || !Number.isFinite(end)) continue;
    const s = Math.max(prevEnd, Math.max(0, start));
    const e = Number.isFinite(end) && end > s ? end : s + 1.2;
    timings.push({ text, start: Math.round(s * 100) / 100, end: Math.round(e * 100) / 100 });
    prevEnd = e;
  }
  if (!timings.length) {
    return NextResponse.json({ error: "No usable timings" }, { status: 400 });
  }

  const { data: sub, error: subErr } = await supabase
    .from("submissions")
    .select("id, user_id")
    .eq("id", body.submissionId)
    .maybeSingle();
  if (subErr) return NextResponse.json({ error: "Could not load that song" }, { status: 500 });
  if (!sub || sub.user_id !== user.id) {
    return NextResponse.json({ error: "Song not found" }, { status: 404 });
  }

  const { error: updErr } = await supabase
    .from("submissions")
    .update({
      lyrics_timing: timings,
      timing_source: "manual",
      timing_updated_at: new Date().toISOString(),
    })
    .eq("id", sub.id);

  if (updErr) {
    console.error("[timing] update failed:", updErr);
    return NextResponse.json({ error: "Could not save your timings" }, { status: 500 });
  }

  return NextResponse.json({ ok: true, lines: timings.length });
}
