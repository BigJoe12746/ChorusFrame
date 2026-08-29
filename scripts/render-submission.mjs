// Manual render for one Supabase submission — the concierge path.
// The self-serve path is the queue: see scripts/render-worker.mjs.
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

import {
  FORMATS,
  loadEnv,
  makeClient,
  renderFormats,
  uploadClips,
} from "./lib/render.mjs";

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
      // "all" keeps its long-standing meaning: the three clip sizes. The
      // Canvas loop is asked for by name — it's silent and Pro-flavoured,
      // not part of the standard concierge kit.
      raw === "all" ? ["vertical", "square", "wide"] : raw.split(",").map((f) => f.trim()).filter(Boolean);
    const unknown = flags.formats.filter((f) => !FORMATS[f]);
    if (unknown.length) {
      fail(`Unknown format(s): ${unknown.join(", ")}. Valid: ${Object.keys(FORMATS).join(", ")}, all`);
    }
    if (!flags.formats.length) fail("--formats needs at least one format");
  } else if (!a.startsWith("--")) submissionId = a;
  else fail(`Unknown option: ${a}`);
}
if (!flags.latest && !submissionId) {
  fail("Pass a submission id or --latest. Example: node scripts/render-submission.mjs --latest");
}
if (flags.out && flags.formats.length > 1) {
  fail("--out works with a single format; drop it when rendering multiple formats");
}

let env, supabase;
try {
  env = loadEnv();
  supabase = makeClient(env);
} catch (e) {
  fail(e.message);
}

// --- fetch submission ---
let query = supabase.from("submissions").select("*");
query = flags.latest
  ? query.eq("status", "queued").order("created_at", { ascending: false }).limit(1)
  : query.eq("id", submissionId).limit(1);
const { data: rows, error: fetchErr } = await query;
if (fetchErr) fail(`Fetching submission failed: ${fetchErr.message}`);
if (!rows?.length) {
  fail(flags.latest ? "No queued submissions found." : `No submission with id ${submissionId}`);
}
const sub = rows[0];
console.log(`▶ "${sub.song_title}" by ${sub.artist_name || "unknown artist"} (${sub.id})`);
console.log(`▶ Formats: ${flags.formats.map((f) => FORMATS[f].label).join(", ")}`);

// Claim the row so a concurrent run (or the worker) can't double-render it
let claimHeld = false;
if (sub.status === "queued") {
  const { data: claimed, error: claimErr } = await supabase
    .from("submissions")
    .update({ status: "in_progress" })
    .eq("id", sub.id)
    .eq("status", "queued")
    .select();
  if (claimErr) fail(`Claiming submission failed: ${claimErr.message}`);
  if (!claimed?.length) fail("Submission was claimed by another run — try again for the next one.");
  claimHeld = true;
}
async function releaseClaim() {
  if (!claimHeld) return;
  claimHeld = false;
  await supabase
    .from("submissions")
    .update({ status: "queued" })
    .eq("id", sub.id)
    .eq("status", "in_progress");
}
process.on("SIGINT", () => {
  releaseClaim().finally(() => process.exit(130));
});

try {
  const rendered = await renderFormats({
    supabase,
    sub,
    formats: flags.formats,
    start: flags.start,
    duration: flags.duration,
    endCard: flags.endCard,
    artworkColors: flags.artworkColors,
    endCardUrl: env.NEXT_PUBLIC_SITE_URL || "",
    env,
    outFile: flags.out,
  });

  if (flags.upload) {
    // Per-run prefix (no dashes — the format is parsed off the last segment),
    // and a done job row: the dashboard and share page read render history
    // now, so an upload that isn't in the job table is invisible.
    const prefix = `manual${Date.now().toString(36)}`;
    const urls = await uploadClips(supabase, sub.id, rendered, { prefix });
    const primary = urls.find((u) => u.format === "vertical") ?? urls[0];
    const { error: jobErr } = await supabase.from("render_jobs").insert({
      submission_id: sub.id,
      user_id: sub.user_id ?? null,
      formats: rendered.map((r) => r.format),
      clip_start_seconds: flags.start,
      duration_seconds: flags.duration,
      status: "done",
      attempts: 1,
      clip_urls: urls,
      finished_at: new Date().toISOString(),
    });
    if (jobErr) throw new Error(`Recording the render failed: ${jobErr.message}`);
    // The metrics read renders from render_jobs, so the row above already
    // counts; this marks it as the concierge path rather than self-serve.
    await supabase
      .from("events")
      .insert({
        name: "render_done",
        user_id: sub.user_id ?? null,
        path: "cli",
        props: { formats: rendered.map((r) => r.format), concierge: true },
      })
      .then(({ error }) => error && console.warn(`(event not recorded: ${error.message})`));
    const { error: updErr } = await supabase
      .from("submissions")
      .update({ sample_clip_url: primary.url, status: "clip_ready" })
      .eq("id", sub.id);
    if (updErr) throw new Error(`Updating submission row failed: ${updErr.message}`);
    claimHeld = false; // row is clip_ready now; nothing to release

    console.log("");
    for (const { format, url } of urls) console.log(`✔ ${format}: ${url}`);
    console.log("✔ Submission marked clip_ready — email the artist, then set status to delivered.");
  } else {
    await releaseClaim(); // local render only: put the row back in the queue
  }
} catch (e) {
  await releaseClaim();
  fail(e.message);
}
