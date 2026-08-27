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

const { data: files } = await supabase.storage.from("clips").list(id);
const names = (files ?? []).map((f) => `${id}/${f.name}`);
if (names.length) {
  const { error: rmErr } = await supabase.storage.from("clips").remove(names);
  if (rmErr) throw new Error(`flag set but clip delete failed: ${rmErr.message}`);
}

console.log(
  `took down "${sub.song_title}": share page hidden, ${names.length} public file(s) deleted (reason: ${reason})`
);
console.log("sources kept in the private bucket; --restore reverses the flag");
