import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

/**
 * Delete a song and everything made from it.
 *
 * Actually deletes: the master audio, the artwork, every rendered clip, and
 * the row. Removing only the row would leave the files sitting in storage
 * counting against the artist's quota forever, and would make the privacy
 * policy's deletion promise untrue.
 *
 * render_jobs rows go with it through the foreign key's ON DELETE CASCADE.
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

  const { data: sub, error: subErr } = await supabase
    .from("submissions")
    .select("id, user_id, song_title, song_path, artwork_path")
    .eq("id", body.submissionId)
    .maybeSingle();
  if (subErr) return NextResponse.json({ error: "Could not load that song" }, { status: 500 });
  // Same answer whether it is missing or someone else's
  if (!sub || sub.user_id !== user.id) {
    return NextResponse.json({ error: "Song not found" }, { status: 404 });
  }

  // Refuse while work is in flight: the worker would carry on rendering a song
  // that no longer exists and fail in a way the artist cannot interpret.
  const { data: busy } = await supabase
    .from("render_jobs")
    .select("id")
    .eq("submission_id", sub.id)
    .in("status", ["queued", "rendering"])
    .limit(1);
  if (busy?.length) {
    return NextResponse.json(
      { error: "That song is rendering right now. Wait for it to finish, then delete." },
      { status: 409 }
    );
  }

  // Clips first. If this fails we stop, rather than deleting the row and
  // orphaning the files with nothing left pointing at them. The listing is
  // PAGED: storage returns at most 100 names per call, and per-render keying
  // means a much-rendered song can hold more than that — a single unpaged
  // list would silently orphan everything past the first page.
  const clipNames: string[] = [];
  for (let offset = 0; ; offset += 100) {
    const { data: page, error: listErr } = await supabase.storage
      .from("clips")
      .list(sub.id, { limit: 100, offset });
    if (listErr) {
      console.error("[delete] clips list:", listErr);
      return NextResponse.json({ error: "Could not remove the clips" }, { status: 500 });
    }
    clipNames.push(...(page ?? []).map((f) => `${sub.id}/${f.name}`));
    if (!page || page.length < 100) break;
  }
  if (clipNames.length) {
    const { error } = await supabase.storage.from("clips").remove(clipNames);
    if (error) {
      console.error("[delete] clips:", error);
      return NextResponse.json({ error: "Could not remove the clips" }, { status: 500 });
    }
  }

  const sources = [sub.song_path, sub.artwork_path].filter(Boolean) as string[];
  if (sources.length) {
    const { error } = await supabase.storage.from("submissions").remove(sources);
    if (error) {
      console.error("[delete] sources:", error);
      return NextResponse.json({ error: "Could not remove the audio" }, { status: 500 });
    }
  }

  const { error: rowErr } = await supabase.from("submissions").delete().eq("id", sub.id);
  if (rowErr) {
    console.error("[delete] row:", rowErr);
    return NextResponse.json({ error: "Could not delete the song" }, { status: 500 });
  }

  return NextResponse.json({
    ok: true,
    deleted: { song: sub.song_title, clips: clipNames.length, files: sources.length },
  });
}
