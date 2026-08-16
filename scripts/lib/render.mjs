// Shared render pipeline, used by both the manual CLI (render-submission.mjs)
// and the queue worker (render-worker.mjs). Keeping one copy means a change to
// how clips are produced can't drift between the two entry points.

import { createClient } from "@supabase/supabase-js";
import { readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");

// Format name → Remotion composition id (see remotion/Root.tsx)
export const FORMATS = {
  vertical: { composition: "SampleClip", label: "9:16 vertical (TikTok/Reels/Shorts)" },
  square: { composition: "SampleClipSquare", label: "1:1 square (feed post)" },
  wide: { composition: "SampleClipWide", label: "16:9 wide (YouTube)" },
};

export const MIN_DURATION = 5;
export const MAX_DURATION = 60;

export function loadEnv() {
  const envPath = path.join(ROOT, ".env.local");
  let text;
  try {
    text = readFileSync(envPath, "utf8");
  } catch {
    throw new Error(`.env.local not found at ${envPath}`);
  }
  const env = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (m && !line.trim().startsWith("#")) env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  // Real environment variables win, so the worker can run on a host that
  // injects config instead of shipping a .env.local
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
  const list = formats?.length ? formats : ["vertical"];
  const unknown = list.filter((f) => !FORMATS[f]);
  if (unknown.length) {
    throw new Error(`unknown format(s): ${unknown.join(", ")}. Valid: ${Object.keys(FORMATS).join(", ")}`);
  }
  return list;
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
  artworkColors = true,
  endCardUrl = "",
  outDir = path.join(ROOT, "out"),
  outFile: singleOut = null,
  log = console.log,
}) {
  const list = validateFormats(formats);
  validateWindow({ start, duration });

  const { audioSrc, artworkSrc } = await signInputs(supabase, sub);

  const props = {
    audioSrc,
    artworkSrc,
    songTitle: sub.song_title,
    artistName: sub.artist_name || "",
    lyrics: sub.lyrics || "",
    clipStartSeconds: start,
    durationSeconds: duration,
    showEndCard: endCard,
    endCardUrl,
    useArtworkColors: artworkColors,
  };

  mkdirSync(outDir, { recursive: true });
  const propsFile = path.join(outDir, `${sub.id}-props.json`);
  writeFileSync(propsFile, JSON.stringify(props, null, 2));

  const rendered = [];
  try {
    for (const format of list) {
      const outFile =
        singleOut && list.length === 1
          ? path.resolve(singleOut)
          : path.join(outDir, `${sub.id}-${format}-${duration}s.mp4`);
      const cmd = `npx remotion render remotion/index.ts ${FORMATS[format].composition} "${outFile}" --props="${propsFile}"`;
      log(`▶ ${format}: rendering…`);
      const res = spawnSync(cmd, { cwd: ROOT, shell: true, stdio: "inherit" });
      if (res.status !== 0) throw new Error(`render failed for ${format}`);
      log(`✔ ${format}: ${outFile}`);
      rendered.push({ format, outFile });
    }
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

/** Upload rendered files to the public bucket under stable per-format keys. */
export async function uploadClips(supabase, submissionId, rendered, now = Date.now()) {
  await ensureClipsBucket(supabase);
  const urls = [];
  for (const { format, outFile } of rendered) {
    const clipPath = `${submissionId}/sample-${format}.mp4`;
    const { error } = await supabase.storage.from("clips").upload(clipPath, readFileSync(outFile), {
      contentType: "video/mp4",
      upsert: true,
      cacheControl: "60",
    });
    if (error) throw new Error(`uploading ${format} failed: ${error.message}`);
    const { data: pub } = supabase.storage.from("clips").getPublicUrl(clipPath);
    urls.push({ format, url: `${pub.publicUrl}?v=${now}` }); // bust CDN cache on re-renders
  }
  return urls;
}
