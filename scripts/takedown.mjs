// Take a song's public presence down — the DMCA response path.
//
//   node scripts/takedown.mjs <submission-id> "reason for the record"
//   node scripts/takedown.mjs <submission-id> --restore
//
// Sets removed_at (which hides the /c/<id> share page) AND deletes the
// public clip files, because anyone who already had a direct file URL could
// otherwise keep fetching it from the bucket. The source audio and artwork
// stay in the private bucket, so if a dispute resolves the artist's way,
// --restore clears the flag and one re-render brings the clips back.

import { loadEnv, makeClient } from "./lib/render.mjs";

const [id, ...rest] = process.argv.slice(2);
if (!id) {
  console.error('usage: node scripts/takedown.mjs <submission-id> "reason" | --restore');
  process.exit(1);
}
const restore = rest.includes("--restore");
const reason = restore ? null : rest.join(" ") || "takedown";

const supabase = makeClient(loadEnv());

const { data: sub, error } = await supabase
  .from("submissions")
  .select("id, song_title, removed_at")
  .eq("id", id)
  .maybeSingle();
if (error) throw new Error(error.message);
if (!sub) {
  console.error(`no submission ${id}`);
  process.exit(1);
}

if (restore) {
  const { error: upErr } = await supabase
    .from("submissions")
    .update({ removed_at: null, removed_reason: null })
    .eq("id", id);
  if (upErr) throw new Error(upErr.message);
  console.log(`restored "${sub.song_title}" — share page is live again; re-render to repopulate clips`);
  process.exit(0);
}

const { error: flagErr } = await supabase
  .from("submissions")
  .update({ removed_at: new Date().toISOString(), removed_reason: reason })
  .eq("id", id);
if (flagErr) throw new Error(flagErr.message);

// Paged: storage lists at most 100 names per call, and per-render keying
// can push a much-rendered song past that. A takedown that misses page two
// is not a takedown.
const names = [];
for (let offset = 0; ; offset += 100) {
  const { data: page, error: listErr } = await supabase.storage
    .from("clips")
    .list(id, { limit: 100, offset });
  if (listErr) throw new Error(`flag set but clip listing failed: ${listErr.message}`);
  names.push(...(page ?? []).map((f) => `${id}/${f.name}`));
  if (!page || page.length < 100) break;
}
if (names.length) {
  const { error: rmErr } = await supabase.storage.from("clips").remove(names);
  if (rmErr) throw new Error(`flag set but clip delete failed: ${rmErr.message}`);
}

// The job rows still point at the files we just deleted; clear them so the
// share page and dashboard stop advertising dead videos (and a --restore
// shows an honest empty state until the artist re-renders).
const { error: urlErr } = await supabase
  .from("render_jobs")
  .update({ clip_urls: null })
  .eq("submission_id", id);
if (urlErr) throw new Error(`files deleted but clearing job urls failed: ${urlErr.message}`);

console.log(
  `took down "${sub.song_title}": share page hidden, ${names.length} public file(s) deleted (reason: ${reason})`
);
console.log("sources kept in the private bucket; --restore reverses the flag");
