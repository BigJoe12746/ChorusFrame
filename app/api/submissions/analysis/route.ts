import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

/**
 * Store the beat grid the browser worked out while decoding the waveform.
 *
 * The worker can't do this itself without shipping an audio decoder, and the
 * browser has already paid the cost of decoding, so the detection happens
 * where the samples are and the result travels with the song.
 */
export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Sign in first" }, { status: 401 });

  const supabase = getSupabaseAdmin();
  if (!supabase) return NextResponse.json({ error: "Not configured" }, { status: 503 });

  const body = await req.json().catch(() => null);
  if (!body || typeof body.submissionId !== "string") {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }

  const bpm = Number(body.bpm);
  const offset = Number(body.beatOffset);
  // Outside this range it isn't a tempo we'd animate to, and a bad grid is
  // worse than none: motion would land consistently off the beat.
  if (!Number.isFinite(bpm) || bpm < 50 || bpm > 220) {
    return NextResponse.json({ error: "Implausible tempo" }, { status: 400 });
  }
  if (!Number.isFinite(offset) || offset < 0 || offset > 10) {
    return NextResponse.json({ error: "Implausible beat offset" }, { status: 400 });
  }

  const { data: sub } = await supabase
    .from("submissions")
    .select("id, user_id")
    .eq("id", body.submissionId)
    .maybeSingle();
  if (!sub || sub.user_id !== user.id) {
    return NextResponse.json({ error: "Song not found" }, { status: 404 });
  }

  const { error } = await supabase
    .from("submissions")
    .update({ bpm, beat_offset: offset })
    .eq("id", sub.id);
  if (error) {
    console.error("[analysis] update failed:", error);
    return NextResponse.json({ error: "Could not save" }, { status: 500 });
  }

  return NextResponse.json({ ok: true, bpm, beatOffset: offset });
}
