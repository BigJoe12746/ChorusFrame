// Render sample clips for a Supabase submission — one project, every format.
//
// Usage:
//   node scripts/render-submission.mjs --latest                 # newest queued submission
//   node scripts/render-submission.mjs <submission-id>
//   Options:
//     --formats vertical,square,wide   which cuts to render (default: vertical; "all" = every format)
//     --start <sec> --duration <sec>   clip window (default: 0, 15)
//     --no-end-card                    drop the "Made with ChorusFrame" outro
//     --brand-colors                   use brand accents instead of cover-art colors
//     --upload                         push to the public `clips` bucket + mark the row clip_ready
//     --out <file>                     override the output path (single format only)
//
// If a run is killed hard (power loss), a row may be left status=in_progress;
// reset it to 'queued' in the Table Editor.

import { createClient } from "@supabase/supabase-js";
import { readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// Format name → Remotion composition id (see remotion/Root.tsx)
const FORMATS = {
  vertical: { composition: "SampleClip", label: "9:16 vertical (TikTok/Reels/Shorts)" },
  square: { composition: "SampleClipSquare", label: "1:1 square (feed post)" },
  wide: { composition: "SampleClipWide", label: "16:9 wide (YouTube)" },
};

function loadEnv() {
  const envPath = path.join(root, ".env.local");
  let text;
  try {
    text = readFileSync(envPath, "utf8");
  } catch {
    fail(`.env.local not found at ${envPath}`);
  }
  const env = {};
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (m && !line.trim().startsWith("#")) env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  return env;
}

function fail(msg) {
  console.error(`✖ ${msg}`);
  process.exit(1);
}

// --- args ---
const argv = process.argv.slice(2);
const flags = {
  start: 0,
  duration: 15,
  upload: false,
  endCard: true,
  artworkColors: true,
  out: null,
  latest: false,
  formats: ["vertical"],
};
let submissionId = null;
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  const takeValue = () => {
    const v = argv[++i];
    if (v === undefined || v.startsWith("--")) fail(`${a} requires a value`);
    return v;
  };
  if (a === "--latest") flags.latest = true;
  else if (a === "--upload") flags.upload = true;
  else if (a === "--no-end-card") flags.endCard = false;
  else if (a === "--brand-colors") flags.artworkColors = false;
  else if (a === "--start") flags.start = Number(takeValue());
  else if (a === "--duration") flags.duration = Number(takeValue());
  else if (a === "--out") flags.out = takeValue();
  else if (a === "--formats") {
    const raw = takeValue().toLowerCase();
    flags.formats =
      raw === "all"
        ? Object.keys(FORMATS)
        : raw.split(",").map((f) => f.trim()).filter(Boolean);
    const unknown = flags.formats.filter((f) => !FORMATS[f]);
    if (unknown.length) fail(`Unknown format(s): ${unknown.join(", ")}. Valid: ${Object.keys(FORMATS).join(", ")}, all`);
    if (!flags.formats.length) fail("--formats needs at least one format");
  } else if (!a.startsWith("--")) submissionId = a;
  else fail(`Unknown option: ${a}`);
}
if (!flags.latest && !submissionId) {
  fail("Pass a submission id or --latest. Example: node scripts/render-submission.mjs --latest");
}
if (!Number.isFinite(flags.start) || flags.start < 0) fail("--start must be a non-negative number of seconds");
if (!Number.isFinite(flags.duration) || flags.duration < 5 || flags.duration > 60) {
  fail("--duration must be between 5 and 60 seconds");
}
if (flags.out && flags.formats.length > 1) {
  fail("--out works with a single format; drop it when rendering multiple formats");
}

const env = loadEnv();
const url = env.NEXT_PUBLIC_SUPABASE_URL;
const key = env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key || url.includes("PASTE") || key.includes("PASTE")) {
  fail("Supabase env vars missing in .env.local");
}
const supabase = createClient(url, key, { auth: { persistSession: false } });

// --- fetch submission ---
let query = supabase.from("submissions").select("*");
query = flags.latest
  ? query.eq("status", "queued").order("created_at", { ascending: false }).limit(1)
  : query.eq("id", submissionId).limit(1);
const { data: rows, error: fetchErr } = await query;
if (fetchErr) fail(`Fetching submission failed: ${fetchErr.message}`);
if (!rows || rows.length === 0) {
  fail(flags.latest ? "No queued submissions found." : `No submission with id ${submissionId}`);
}
const sub = rows[0];
console.log(`▶ "${sub.song_title}" by ${sub.artist_name || "unknown artist"} (${sub.id})`);
console.log(`▶ Formats: ${flags.formats.map((f) => FORMATS[f].label).join(", ")}`);

// Claim the row so a concurrent --latest run can't double-render it
let claimHeld = false;
if (sub.status === "queued") {
  const { data: claimed, error: claimErr } = await supabase
    .from("submissions")
    .update({ status: "in_progress" })
    .eq("id", sub.id)
    .eq("status", "queued")
    .select();
  if (claimErr) fail(`Claiming submission failed: ${claimErr.message}`);
  if (!claimed || claimed.length === 0) {
    fail("Submission was claimed by another run — try again for the next one.");
  }
  claimHeld = true;
}
async function releaseClaim() {
  if (claimHeld) {
    claimHeld = false;
    await supabase.from("submissions").update({ status: "queued" }).eq("id", sub.id).eq("status", "in_progress");
  }
}
process.on("SIGINT", () => {
  releaseClaim().finally(() => process.exit(130));
});

// Everything after the claim throws instead of exiting, so the catch below
// can put the row back to 'queued' before the process dies.
try {
  // --- signed URLs for the private bucket (4h: outlives any realistic render) ---
  async function sign(objectPath) {
    const { data, error } = await supabase.storage.from("submissions").createSignedUrl(objectPath, 14400);
    if (error) throw new Error(`Signing URL for ${objectPath} failed: ${error.message}`);
    return data.signedUrl;
  }
  const audioSrc = await sign(sub.song_path);
  const artworkSrc = sub.artwork_path ? await sign(sub.artwork_path) : null;

  // --- render ---
  // The composition itself validates the clip window against the real audio
  // duration (calculateMetadata) and fails the render loudly on overrun.
  const props = {
    audioSrc,
    artworkSrc,
    songTitle: sub.song_title,
    artistName: sub.artist_name || "",
    lyrics: sub.lyrics || "",
    clipStartSeconds: flags.start,
    durationSeconds: flags.duration,
    showEndCard: flags.endCard,
    endCardUrl: env.NEXT_PUBLIC_SITE_URL || "",
    useArtworkColors: flags.artworkColors,
  };

  const outDir = path.join(root, "out");
  mkdirSync(outDir, { recursive: true });
  const propsFile = path.join(outDir, `${sub.id}-props.json`);
  writeFileSync(propsFile, JSON.stringify(props, null, 2));

  const rendered = [];
  try {
    for (const format of flags.formats) {
      const outFile = flags.out
        ? path.resolve(flags.out)
        : path.join(outDir, `${sub.id}-${format}-${flags.duration}s.mp4`);
      const cmd = `npx remotion render remotion/index.ts ${FORMATS[format].composition} "${outFile}" --props="${propsFile}"`;
      console.log(`\n▶ ${format}: ${cmd}`);
      const res = spawnSync(cmd, { cwd: root, shell: true, stdio: "inherit" });
      if (res.status !== 0) throw new Error(`Remotion render failed for ${format} (see output above).`);
      console.log(`✔ Rendered ${outFile}`);
      rendered.push({ format, outFile });
    }
  } finally {
    rmSync(propsFile, { force: true }); // contains signed URLs — don't leave it around
  }

  // --- optional upload ---
  if (flags.upload) {
    const { error: bucketErr } = await supabase.storage.createBucket("clips", { public: true });
    if (bucketErr) {
      // Bucket may already exist — verify it does and is public rather than trusting the error text
      const { data: bucket, error: getErr } = await supabase.storage.getBucket("clips");
      if (getErr || !bucket) throw new Error(`Creating clips bucket failed: ${bucketErr.message}`);
      if (!bucket.public) {
        throw new Error(
          "A 'clips' bucket exists but is private — this script won't silently make it public. " +
            "Mark it public in the Supabase dashboard (Storage → clips → settings) if that's intended."
        );
      }
    }

    const urls = [];
    for (const { format, outFile } of rendered) {
      // Stable key per format so re-renders replace the old clip instead of orphaning it
      const clipPath = `${sub.id}/sample-${format}.mp4`;
      const { error: upErr } = await supabase.storage
        .from("clips")
        .upload(clipPath, readFileSync(outFile), {
          contentType: "video/mp4",
          upsert: true,
          cacheControl: "60",
        });
      if (upErr) throw new Error(`Uploading ${format} clip failed: ${upErr.message}`);
      const { data: pub } = supabase.storage.from("clips").getPublicUrl(clipPath);
      urls.push({ format, url: `${pub.publicUrl}?v=${Date.now()}` }); // bust CDN cache on re-renders
    }

    // The row holds one URL: the vertical cut if we made one, else the first.
    const primary = urls.find((u) => u.format === "vertical") ?? urls[0];
    const { error: updErr } = await supabase
      .from("submissions")
      .update({ sample_clip_url: primary.url, status: "clip_ready" })
      .eq("id", sub.id);
    if (updErr) throw new Error(`Updating submission row failed: ${updErr.message}`);
    claimHeld = false; // row is now clip_ready; nothing to release

    console.log("");
    for (const { format, url: u } of urls) console.log(`✔ ${format}: ${u}`);
    console.log(`✔ Submission marked clip_ready — email the artist, then set status to delivered.`);
  } else {
    await releaseClaim(); // local render only: put the row back in the queue
  }
} catch (e) {
  await releaseClaim();
  fail(e.message);
}
