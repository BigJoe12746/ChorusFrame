import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

const MAX_AUDIO_BYTES = 50 * 1024 * 1024; // 50 MB
const MAX_ART_BYTES = 10 * 1024 * 1024; // 10 MB
const AUDIO_TYPES = ["audio/mpeg", "audio/wav", "audio/x-wav", "audio/mp3"];
const ART_TYPES = ["image/jpeg", "image/png", "image/webp"];

function safeName(name: string) {
  return name.replace(/[^a-zA-Z0-9._-]/g, "_").slice(-80);
}

export async function POST(req: Request) {
  const form = await req.formData().catch(() => null);
  if (!form) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }

  const email = String(form.get("email") ?? "").trim().toLowerCase();
  const artistName = String(form.get("artistName") ?? "").trim();
  const songTitle = String(form.get("songTitle") ?? "").trim();
  const lyrics = String(form.get("lyrics") ?? "").trim();
  const song = form.get("song");
  const artwork = form.get("artwork");

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ error: "Enter a valid email" }, { status: 400 });
  }
  if (!songTitle) {
    return NextResponse.json({ error: "Enter a song title" }, { status: 400 });
  }
  if (!(song instanceof File) || song.size === 0) {
    return NextResponse.json({ error: "Attach your song (WAV or MP3)" }, { status: 400 });
  }
  if (song.size > MAX_AUDIO_BYTES) {
    return NextResponse.json({ error: "Song file must be under 50 MB" }, { status: 400 });
  }
  if (song.type && !AUDIO_TYPES.includes(song.type)) {
    return NextResponse.json({ error: "Song must be a WAV or MP3 file" }, { status: 400 });
  }
  if (artwork instanceof File && artwork.size > 0) {
    if (artwork.size > MAX_ART_BYTES) {
      return NextResponse.json({ error: "Artwork must be under 10 MB" }, { status: 400 });
    }
    if (artwork.type && !ART_TYPES.includes(artwork.type)) {
      return NextResponse.json({ error: "Artwork must be JPG, PNG, or WebP" }, { status: 400 });
    }
  }

  const supabase = getSupabaseAdmin();
  if (!supabase) {
    console.warn("[submissions] Supabase not configured — demo mode, not persisted:", email, songTitle);
    return NextResponse.json({ ok: true, demo: true });
  }

  const id = crypto.randomUUID();
  const songPath = `${id}/${safeName(song.name || "song.mp3")}`;

  const { error: songErr } = await supabase.storage
    .from("submissions")
    .upload(songPath, song, { contentType: song.type || "audio/mpeg" });
  if (songErr) {
    console.error("[submissions] song upload failed:", songErr);
    return NextResponse.json({ error: "Upload failed. Try again." }, { status: 500 });
  }

  let artworkPath: string | null = null;
  if (artwork instanceof File && artwork.size > 0) {
    artworkPath = `${id}/${safeName(artwork.name || "artwork.jpg")}`;
    const { error: artErr } = await supabase.storage
      .from("submissions")
      .upload(artworkPath, artwork, { contentType: artwork.type || "image/jpeg" });
    if (artErr) {
      console.error("[submissions] artwork upload failed:", artErr);
      artworkPath = null; // artwork is optional — keep going
    }
  }

  // Attribute the upload when the artist is signed in; anonymous uploads
  // (the free-sample flow) keep user_id null and stay service-role-only.
  const user = await getCurrentUser();

  const { error: dbErr } = await supabase.from("submissions").insert({
    id,
    email,
    artist_name: artistName || null,
    song_title: songTitle,
    lyrics: lyrics || null,
    song_path: songPath,
    artwork_path: artworkPath,
    status: "queued",
    user_id: user?.id ?? null,
  });

  if (dbErr) {
    console.error("[submissions] insert failed:", dbErr);
    return NextResponse.json({ error: "Something went wrong. Try again." }, { status: 500 });
  }

  return NextResponse.json({ ok: true, id });
}
