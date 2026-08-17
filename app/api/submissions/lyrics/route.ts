import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

const MAX_LYRICS = 20000;

/**
 * Update the lyrics on a song you already uploaded.
 *
 * Without this, an artist who skipped the lyrics box at upload time could never
 * add them — their song was permanently stuck producing a visualizer instead of
 * the lyric video the product promises.
 *
 * Changing the words invalidates any cached alignment: timings computed for the
 * old lyrics would put the wrong line on screen at the right moment.
 */
export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Sign in first" }, { status: 401 });

  const supabase = getSupabaseAdmin();
  if (!supabase) return NextResponse.json({ error: "Not configured" }, { status: 503 });

  const body = await req.json().catch(() => null);
  if (!body || typeof body.submissionId !== "string" || typeof body.lyrics !== "string") {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
  const lyrics = body.lyrics.slice(0, MAX_LYRICS).trim();

  const { data: sub, error: subErr } = await supabase
    .from("submissions")
    .select("id, user_id, lyrics")
    .eq("id", body.submissionId)
    .maybeSingle();
  if (subErr) return NextResponse.json({ error: "Could not load that song" }, { status: 500 });
  // Same answer whether it's missing or someone else's
  if (!sub || sub.user_id !== user.id) {
    return NextResponse.json({ error: "Song not found" }, { status: 404 });
  }

  const changed = (sub.lyrics ?? "").trim() !== lyrics;
  const { error: updErr } = await supabase
    .from("submissions")
    .update({
      lyrics: lyrics || null,
      // Drop stale timing so the next render re-aligns against the new words
      ...(changed ? { lyrics_timing: null, timing_source: null } : {}),
    })
    .eq("id", sub.id);

  if (updErr) {
    console.error("[lyrics] update failed:", updErr);
    return NextResponse.json({ error: "Could not save your lyrics" }, { status: 500 });
  }

  return NextResponse.json({ ok: true, lines: lyrics ? lyrics.split(/\r?\n/).filter(Boolean).length : 0 });
}
