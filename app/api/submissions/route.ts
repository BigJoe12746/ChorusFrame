import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

const MAX_AUDIO_BYTES = 50 * 1024 * 1024; // 50 MB
const MAX_ART_BYTES = 10 * 1024 * 1024; // 10 MB
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Record a submission whose files are already in storage.
 *
 * The audio never passes through here — it goes browser-to-storage via a
 * signed URL from /api/submissions/upload-url, because Vercel caps request
 * bodies at ~4.5MB and a normal MP3 is larger than that.
 *
 * Sizes are enforced against what actually landed rather than what the browser
 * claimed, since a signed upload URL is a direct line to storage.
 */
export async function POST(req: Request) {
  const supabase = getSupabaseAdmin();
  if (!supabase) {
    console.warn("[submissions] Supabase not configured — demo mode");
    return NextResponse.json({ ok: true, demo: true });
  }

  const body = await req.json().catch(() => null);
  if (!body) return NextResponse.json({ error: "Invalid request" }, { status: 400 });

  const id = String(body.id ?? "");
  const email = String(body.email ?? "").trim().toLowerCase();
  const artistName = String(body.artistName ?? "").trim();
  const songTitle = String(body.songTitle ?? "").trim().slice(0, 200);
  const lyrics = String(body.lyrics ?? "").trim().slice(0, 20000);
  const songPath = String(body.songPath ?? "");
  const artworkPath = body.artworkPath ? String(body.artworkPath) : null;

  if (!UUID.test(id)) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ error: "Enter a valid email" }, { status: 400 });
  }
  if (!songTitle) {
    return NextResponse.json({ error: "Enter a song title" }, { status: 400 });
  }
  // The upload form can't submit without this box, so its absence here means
  // the API was called directly — refuse, and record the affirmation below so
  // the copyright policy's "everyone who uploads confirms..." is auditable.
  if (body.rightsConfirmed !== true) {
    return NextResponse.json(
      { error: "Confirm you hold the rights to this music and artwork" },
      { status: 400 }
    );
  }
  // Paths must sit under the id this request was issued, so a caller can't
  // attach someone else's uploaded audio to their own submission.
  if (!songPath.startsWith(`${id}/`) || (artworkPath && !artworkPath.startsWith(`${id}/`))) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }

  // Confirm the files really arrived, and are the size they should be
  const { data: files, error: listErr } = await supabase.storage
    .from("submissions")
    .list(id);
  if (listErr) {
    console.error("[submissions] list failed:", listErr);
    return NextResponse.json({ error: "Could not verify the upload" }, { status: 500 });
  }
  const byName = new Map((files ?? []).map((f) => [f.name, f]));
  const songFile = byName.get(songPath.slice(id.length + 1));
  if (!songFile) {
    return NextResponse.json({ error: "The song didn't finish uploading" }, { status: 400 });
  }
  const songSize = (songFile.metadata as { size?: number } | null)?.size ?? 0;
  if (songSize === 0) {
    return NextResponse.json({ error: "That song file is empty" }, { status: 400 });
  }
  if (songSize > MAX_AUDIO_BYTES) {
    await supabase.storage.from("submissions").remove([songPath]);
    return NextResponse.json({ error: "Song file must be under 50 MB" }, { status: 400 });
  }

  let art = artworkPath;
  if (art) {
    const artFile = byName.get(art.slice(id.length + 1));
    const artSize = (artFile?.metadata as { size?: number } | null)?.size ?? 0;
    if (!artFile || artSize === 0 || artSize > MAX_ART_BYTES) {
      if (artFile) await supabase.storage.from("submissions").remove([art]);
      art = null; // artwork is optional — keep the submission
    }
  }

  // Attribute the upload when the artist is signed in; anonymous uploads
  // (the free-sample flow) keep user_id null and stay service-role-only.
  const user = await getCurrentUser();

  const row = {
    id,
    email,
    artist_name: artistName || null,
    song_title: songTitle,
    lyrics: lyrics || null,
    song_path: songPath,
    artwork_path: art,
    status: "queued",
    user_id: user?.id ?? null,
  };
  // rights_confirmed_at arrives with migration 009. Until it's applied,
  // retrying without the column keeps uploads working — the affirmation is
  // still enforced above, just not yet stored.
  let { error: dbErr } = await supabase
    .from("submissions")
    .insert({ ...row, rights_confirmed_at: new Date().toISOString() });
  if (
    dbErr &&
    (dbErr.code === "PGRST204" || dbErr.code === "42703") &&
    /rights_confirmed_at/.test(dbErr.message)
  ) {
    console.warn(
      "[submissions] rights_confirmed_at column missing — apply supabase/009_trust.sql so affirmations are recorded"
    );
    ({ error: dbErr } = await supabase.from("submissions").insert(row));
  }

  if (dbErr) {
    console.error("[submissions] insert failed:", dbErr);
    return NextResponse.json({ error: "Something went wrong. Try again." }, { status: 500 });
  }

  return NextResponse.json({ ok: true, id });
}
