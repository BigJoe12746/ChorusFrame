// Shared render pipeline, used by both the manual CLI (render-submission.mjs)
// and the queue worker (render-worker.mjs). Keeping one copy means a change to
// how clips are produced can't drift between the two entry points.

import { createClient } from "@supabase/supabase-js";
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync, statSync } from "node:fs";
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { estimateTimings, splitLines, timingsForWindow } from "./align.mjs";
import { ensureLyricTiming } from "./timing.mjs";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

// Format name → Remotion composition id (see remotion/Root.tsx)
export const FORMATS = {
  vertical: { composition: "SampleClip", label: "9:16 vertical (TikTok/Reels/Shorts)" },
  square: { composition: "SampleClipSquare", label: "1:1 square (feed post)" },
  wide: { composition: "SampleClipWide", label: "16:9 wide (YouTube)" },
};

export const MIN_DURATION = 5;
export const MAX_DURATION = 60;
const FPS = 30;

/**
 * How many lines a clip of this length can actually show and still be read.
 * Mirrors the budget the composition applies (~26 frames minimum per line:
 * enough to spring in, hold, and fade), so the two never disagree.
 */
export function readableLines(lines, durationSeconds) {
  const budget = Math.min(10, Math.max(1, Math.floor((durationSeconds * FPS - 54) / 26)));
  return lines.slice(0, budget);
}

/**
 * Config from .env.local when present, overlaid with real environment
 * variables. A deployed worker has no .env.local — the host injects the
 * config — so a missing file is normal, not an error.
 */
export function loadEnv() {
  const envPath = path.join(ROOT, ".env.local");
  const env = {};
  let text = null;
  try {
    text = readFileSync(envPath, "utf8");
  } catch {
    // No local env file: rely entirely on the process environment.
  }
  for (const line of (text ?? "").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (m && !line.trim().startsWith("#")) env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  return { ...env, ...process.env };
}

export function makeClient(env) {
  const url = env.NEXT_PUBLIC_SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key || url.includes("PASTE") || key.includes("PASTE")) {
    throw new Error("Supabase env vars missing (NEXT_PUBLIC_SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)");
  }
  return createClient(url, key, { auth: { persistSession: false } });
}

export function validateWindow({ start, duration }) {
  if (!Number.isFinite(start) || start < 0) {
    throw new Error("clip start must be a non-negative number of seconds");
  }
  if (!Number.isFinite(duration) || duration < MIN_DURATION || duration > MAX_DURATION) {
    throw new Error(`duration must be between ${MIN_DURATION} and ${MAX_DURATION} seconds`);
  }
}

export function validateFormats(formats) {
  // Dedupe: a stored row could otherwise ask for the same format repeatedly
  // and multiply the work for a single job.
  const list = [...new Set(formats?.length ? formats : ["vertical"])];
  const unknown = list.filter((f) => !Object.hasOwn(FORMATS, f));
  if (unknown.length) {
    throw new Error(`unknown format(s): ${unknown.join(", ")}. Valid: ${Object.keys(FORMATS).join(", ")}`);
  }
  return list;
}

/**
 * Run a command to completion WITHOUT blocking the event loop.
 *
 * This has to stay async: the worker's heartbeat is a timer, and spawnSync
 * would starve it for the whole render — which made every long render look
 * abandoned and get reclaimed and re-rendered by a second worker.
 */
/**
 * Locate the Remotion CLI's JS entry so it can be run with this Node binary.
 * The package doesn't expose the bin through its "exports" map, so resolve the
 * package directory first and fall back to a plain node_modules lookup.
 */
function resolveRemotionCli() {
  const req = createRequire(import.meta.url);
  const candidates = [];
  for (const spec of ["@remotion/cli/package.json", "@remotion/cli"]) {
    try {
      const resolved = req.resolve(spec);
      const dir = spec.endsWith("package.json")
        ? path.dirname(resolved)
        : path.resolve(path.dirname(resolved), "..");
      candidates.push(path.join(dir, "remotion-cli.js"));
    } catch {
      // try the next strategy
    }
  }
  candidates.push(path.join(ROOT, "node_modules", "@remotion", "cli", "remotion-cli.js"));
  const found = candidates.find((c) => existsSync(c));
  if (!found) {
    throw new Error(`could not locate the Remotion CLI (looked in: ${candidates.join(", ")})`);
  }
  return found;
}

function run(command, args, opts) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { ...opts, stdio: "inherit", shell: false });
    child.on("error", reject);
    child.on("close", (code) =>
      code === 0 ? resolve() : reject(new Error(`${command} exited with code ${code}`))
    );
  });
}

/** Signed URLs for the private submissions bucket. */
export async function signInputs(supabase, sub, seconds = 14400) {
  async function sign(objectPath) {
    const { data, error } = await supabase.storage
      .from("submissions")
      .createSignedUrl(objectPath, seconds);
    if (error) throw new Error(`signing ${objectPath} failed: ${error.message}`);
    return data.signedUrl;
  }
  return {
    audioSrc: await sign(sub.song_path),
    artworkSrc: sub.artwork_path ? await sign(sub.artwork_path) : null,
  };
}

/** Longest side of the copy of the artwork that renders use. */
const RENDER_ART_MAX = 1440;
/** Originals at or under this size are used as-is. */
const RENDER_ART_BYTES = 2 * 1024 * 1024;

/**
 * A render-sized copy of oversized artwork, cached in storage per song.
 *
 * Distribution artwork is routinely 3000x3000 (an 8.6MB PNG in the case that
 * surfaced this): decoded that is a ~36MB bitmap, drawn TWICE per frame —
 * once through a heavy blur at 2.6x scale — which OOMs the render container
 * while sailing through a dev machine. 1440px is comfortably above the
 * largest size the artwork is ever shown at (a 720px card, or full-bleed at
 * 1080 wide) and renders identically.
 *
 * Never fatal: any failure here falls back to the original, because a
 * possibly-heavy render beats no render.
 */
async function ensureRenderArtwork(supabase, sub, log = console.log) {
  if (!sub.artwork_path) return null;
  const dir = sub.artwork_path.split("/")[0];
  const cachedPath = `${dir}/artwork-render.jpg`;
  if (sub.artwork_path.endsWith("artwork-render.jpg")) return sub.artwork_path;

  try {
    // Already made on an earlier render?
    const { data: files } = await supabase.storage.from("submissions").list(dir);
    const existing = (files ?? []).find((f) => f.name === "artwork-render.jpg");
    if (existing) return cachedPath;

    const original = (files ?? []).find((f) => sub.artwork_path.endsWith(`/${f.name}`));
    const size = (original?.metadata && original.metadata.size) || 0;
    if (size > 0 && size <= RENDER_ART_BYTES) return sub.artwork_path;

    const { data: blob, error: dlErr } = await supabase.storage
      .from("submissions")
      .download(sub.artwork_path);
    if (dlErr || !blob) throw new Error(dlErr?.message ?? "download failed");

    const sharp = (await import("sharp")).default;
    const resized = await sharp(Buffer.from(await blob.arrayBuffer()))
      .resize(RENDER_ART_MAX, RENDER_ART_MAX, { fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 92 })
      .toBuffer();

    const { error: upErr } = await supabase.storage
      .from("submissions")
      .upload(cachedPath, resized, { contentType: "image/jpeg", upsert: true });
    if (upErr) throw new Error(upErr.message);

    log(`artwork: ${(size / 1024 / 1024).toFixed(1)}MB original → ${(resized.length / 1024 / 1024).toFixed(1)}MB render copy`);
    return cachedPath;
  } catch (e) {
    log(`artwork downscale skipped (${String(e?.message ?? e).slice(0, 80)}) — using original`);
    return sub.artwork_path;
  }
}

/**
 * Render one submission into the requested formats.
 * The composition validates the clip window against the real audio duration,
 * so an overrun fails here loudly rather than producing silent video.
 */
export async function renderFormats({
  supabase,
  sub,
  formats,
  start = 0,
  duration = 15,
  endCard = true,
  // Watermark removal and the brand kit are paid features; default to the
  // free behavior so a caller that forgets is honest rather than generous.
  watermark = true,
  allowBrandKit = true,
  artworkColors = true,
  endCardUrl = "",
  vibe = null,
  /**
   * Called after each format finishes rendering, before the next begins.
   * The worker uses it to upload and publish clips progressively — the
   * vertical reaches the artist while square and wide are still cooking.
   */
  onFormat = null,
  env = {},
  outDir = path.join(ROOT, "out"),
  outFile: singleOut = null,
  log = console.log,
}) {
  const list = validateFormats(formats);
  validateWindow({ start, duration });

  const renderArt = await ensureRenderArtwork(supabase, sub, log);
  const { audioSrc, artworkSrc } = await signInputs(
    supabase,
    { ...sub, artwork_path: renderArt },
    undefined
  );

  // The artist's saved identity, so their fifth release looks like their first.
  // Pro-only: the kit saves for anyone, but only a paid plan renders with it.
  let brand = null;
  if (allowBrandKit && sub.user_id) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("brand_primary, brand_secondary, brand_font")
      .eq("id", sub.user_id)
      .maybeSingle();
    if (profile?.brand_primary || profile?.brand_secondary || profile?.brand_font) {
      brand = {
        primary: profile.brand_primary,
        secondary: profile.brand_secondary,
        font: profile.brand_font,
      };
      log(`brand kit: ${brand.primary ?? "—"} / ${brand.secondary ?? "—"} / ${brand.font ?? "—"}`);
    }
  }

  // Lyric timing: real alignment when a transcriber is configured (cached on
  // the song), otherwise a syllable-weighted spread across this clip window.
  let lyricTiming = [];
  let timingSource = "none";
  if (sub.lyrics?.trim()) {
    const { timings, source } = await ensureLyricTiming({
      supabase,
      sub,
      audioUrl: audioSrc,
      env,
      log,
    });
    timingSource = source;
    const windowed =
      source === "estimated" ? [] : timingsForWindow(timings, start, duration);
    lyricTiming = windowed.length
      ? windowed
      : // No real timing, or none of it lands in this window: spread the lines
        // across the clip so it still reads as a lyric video.
        //
        // Thin the list FIRST. A full lyric sheet spread over 15 seconds is a
        // strobe nobody can read, and letting the composition truncate the tail
        // instead would bunch every line into the opening seconds and leave the
        // rest of the clip blank.
        estimateTimings(readableLines(splitLines(sub.lyrics), duration), 0, duration);
    log(`lyric timing: ${lyricTiming.length} lines (${timingSource})`);
  }

  const props = {
    audioSrc,
    artworkSrc,
    songTitle: sub.song_title,
    artistName: sub.artist_name || "",
    lyrics: sub.lyrics || "",
    lyricTiming,
    clipStartSeconds: start,
    durationSeconds: duration,
    showEndCard: endCard,
    showWatermark: watermark,
    endCardUrl,
    useArtworkColors: artworkColors,
    // The composition falls back to its default for an unknown id, so a bad
    // value can never fail a render.
    vibe: vibe || sub.vibe || "",
    brand,
    // Detected in the browser and stored on the song; the worker has no
    // audio decoder of its own.
    beatGrid:
      sub.bpm && sub.beat_offset !== null
        ? { bpm: Number(sub.bpm), offset: Number(sub.beat_offset) }
        : null,
  };

  mkdirSync(outDir, { recursive: true });
  // Unique per run: the manual CLI and a worker can legitimately be running
  // against the same submission, and they must not share a props file.
  const runId = `${process.pid}-${Math.round(performance.now())}`;
  const propsFile = path.join(outDir, `${sub.id}-${runId}-props.json`);
  writeFileSync(propsFile, JSON.stringify(props, null, 2));

  // Invoke the Remotion CLI's JS entry point with this same Node binary rather
  // than going through npx. npx is a .cmd shim on Windows, and Node refuses to
  // spawn .cmd files without a shell (EINVAL), while using a shell would put
  // paths on a command line. This avoids both.
  const cli = resolveRemotionCli();

  const rendered = [];
  try {
    for (const format of list) {
      const outFile =
        singleOut && list.length === 1
          ? path.resolve(singleOut)
          : path.join(outDir, `${sub.id}-${runId}-${format}.mp4`);
      log(`▶ ${format}: rendering…`);
      await run(
        process.execPath,
        [
          cli,
          "render",
          "remotion/index.ts",
          FORMATS[format].composition,
          outFile,
          `--props=${propsFile}`,
          // Remotion defaults to near-lossless H.264, which produced files big
          // enough for storage to reject a 30s clip outright. CRF 23 is
          // visually transparent for social video and roughly halves the size,
          // which also means faster uploads and faster downloads for artists.
          "--crf=23",
        ],
        { cwd: ROOT }
      );
      log(`✔ ${format}: ${outFile}`);
      rendered.push({ format, outFile });
      if (onFormat) await onFormat({ format, outFile });
    }
  } catch (e) {
    // Don't leave half-finished files behind for the caller to clean up
    for (const r of rendered) rmSync(r.outFile, { force: true });
    throw e;
  } finally {
    rmSync(propsFile, { force: true }); // holds signed URLs — don't leave it behind
  }
  return rendered;
}

/** Ensure the public clips bucket exists and really is public. */
export async function ensureClipsBucket(supabase) {
  const { error } = await supabase.storage.createBucket("clips", { public: true });
  if (!error) return;
  const { data: bucket, error: getErr } = await supabase.storage.getBucket("clips");
  if (getErr || !bucket) throw new Error(`creating clips bucket failed: ${error.message}`);
  if (!bucket.public) {
    throw new Error(
      "A 'clips' bucket exists but is private — refusing to publish clips to it. " +
        "Mark it public in the Supabase dashboard if that's intended."
    );
  }
}

/** Storage rejects anything past this; checked before we spend the upload. */
export const MAX_CLIP_BYTES = 45 * 1024 * 1024;

/**
 * Upload rendered files to the public bucket.
 *
 * `prefix` keys the files to one render: the worker passes a slice of the job
 * id, so every render keeps its own files and an artist can compare vibes or
 * trust a shared link not to change underneath a follower. The default keeps
 * the legacy stable key for the manual CLI, which deliberately overwrites.
 */
export async function uploadClips(supabase, submissionId, rendered, { prefix = "sample", now = Date.now() } = {}) {
  await ensureClipsBucket(supabase);

  // Check every file first. Discovering "too large" halfway through means some
  // formats are published and others aren't, and the retry re-renders all of
  // them — three times — before the artist is told anything useful.
  const oversized = rendered
    .map(({ format, outFile }) => ({ format, size: statSync(outFile).size }))
    .filter((f) => f.size > MAX_CLIP_BYTES);
  if (oversized.length) {
    const detail = oversized
      .map((f) => `${f.format} is ${(f.size / 1024 / 1024).toFixed(0)}MB`)
      .join(", ");
    throw new Error(
      `clip too large to store (${detail}; limit ${MAX_CLIP_BYTES / 1024 / 1024}MB) — try a shorter clip`
    );
  }

  const urls = [];
  for (const { format, outFile } of rendered) {
    const clipPath = `${submissionId}/${prefix}-${format}.mp4`;
    const { error } = await supabase.storage.from("clips").upload(clipPath, readFileSync(outFile), {
      contentType: "video/mp4",
      upsert: true,
      // A year at the edge: re-renders bust via ?v= on every consumer,
        // so immutable caching is safe and cuts share-page egress ~3x.
        cacheControl: "31536000",
    });
    if (error) throw new Error(`uploading ${format} failed: ${error.message}`);
    const { data: pub } = supabase.storage.from("clips").getPublicUrl(clipPath);
    urls.push({ format, url: `${pub.publicUrl}?v=${now}` }); // bust CDN cache on re-renders
  }
  return urls;
}
