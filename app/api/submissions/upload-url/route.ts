import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

const AUDIO_EXT = /\.(mp3|wav)$/i;
const ART_EXT = /\.(jpe?g|png|webp)$/i;

function safeName(name: string, fallback: string) {
  const cleaned = name.replace(/[^a-zA-Z0-9._-]/g, "_").slice(-80);
  return cleaned.replace(/^_+/, "") || fallback;
}

/**
 * Hand the browser short-lived URLs to upload straight into storage.
 *
 * The file must not travel through this API: Vercel rejects request bodies
 * over ~4.5MB with FUNCTION_PAYLOAD_TOO_LARGE, so a normal 8MB MP3 could never
 * arrive — the form advertised 50MB and simply failed. Going direct also means
 * the audio isn't buffered through a serverless function at all.
 *
 * The paths are chosen here, under a server-generated id, so a caller can't
 * aim an upload at somebody else's folder.
 */
export async function POST(req: Request) {
  const supabase = getSupabaseAdmin();
  if (!supabase) {
    return NextResponse.json({ error: "Uploads aren't configured" }, { status: 503 });
  }

  const body = await req.json().catch(() => null);
  if (!body || typeof body.songName !== "string") {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
  if (!AUDIO_EXT.test(body.songName)) {
    return NextResponse.json({ error: "Song must be a WAV or MP3 file" }, { status: 400 });
  }
  const wantsArt = typeof body.artworkName === "string" && body.artworkName.length > 0;
  if (wantsArt && !ART_EXT.test(body.artworkName)) {
    return NextResponse.json({ error: "Artwork must be JPG, PNG, or WebP" }, { status: 400 });
  }

  const id = crypto.randomUUID();
  const songPath = `${id}/${safeName(body.songName, "song.mp3")}`;

  const { data: song, error: songErr } = await supabase.storage
    .from("submissions")
    .createSignedUploadUrl(songPath);
  if (songErr || !song) {
    console.error("[upload-url] song:", songErr);
    return NextResponse.json({ error: "Could not start the upload" }, { status: 500 });
  }

  let artwork: { path: string; signedUrl: string } | null = null;
  if (wantsArt) {
    const artworkPath = `${id}/${safeName(body.artworkName, "artwork.jpg")}`;
    const { data: art, error: artErr } = await supabase.storage
      .from("submissions")
      .createSignedUploadUrl(artworkPath);
    if (artErr || !art) {
      console.error("[upload-url] artwork:", artErr);
    } else {
      artwork = { path: artworkPath, signedUrl: art.signedUrl };
    }
  }

  return NextResponse.json({
    id,
    song: { path: songPath, signedUrl: song.signedUrl },
    artwork,
  });
}
