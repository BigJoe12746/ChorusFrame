// ChorusFrame render worker.
//
//   npm run worker            # poll forever
//   npm run worker -- --once  # drain the queue and exit (useful in CI/tests)
//
// Claims queued jobs one at a time, renders every requested format, uploads
// them, and marks the job done. A crash mid-render leaves a stale heartbeat,
// and claim_render_job() requeues that job for another worker.
//
// Runs anywhere Node + Chrome can: a laptop today, a container later. Nothing
// in the web app knows or cares where this process lives.

import os from "node:os";
import { rmSync } from "node:fs";
import {
  loadEnv,
  makeClient,
  renderFormats,
  uploadClips,
} from "./lib/render.mjs";

const argv = process.argv.slice(2);
const ONCE = argv.includes("--once");
const POLL_MS = Number(argv[argv.indexOf("--poll") + 1]) > 0 ? Number(argv[argv.indexOf("--poll") + 1]) : 5000;
const HEARTBEAT_MS = 30_000;

const WORKER_ID = `${os.hostname()}-${process.pid}`;
const env = loadEnv();
const supabase = makeClient(env);

const log = (...a) => console.log(new Date().toISOString(), ...a);

let stopping = false;
let currentJobId = null;

async function releaseCurrentJob(reason) {
  if (!currentJobId) return;
  const id = currentJobId;
  currentJobId = null;
  await supabase
    .from("render_jobs")
    .update({ status: "queued", worker_id: null, error: reason })
    .eq("id", id)
    .eq("status", "rendering");
  log(`↩ requeued job ${id}: ${reason}`);
}

for (const sig of ["SIGINT", "SIGTERM"]) {
  process.on(sig, () => {
    if (stopping) process.exit(130);
    stopping = true;
    log(`${sig} received — finishing up…`);
    releaseCurrentJob("worker shut down").finally(() => process.exit(130));
  });
}

async function claim() {
  const { data, error } = await supabase.rpc("claim_render_job", { p_worker: WORKER_ID });
  if (error) throw new Error(`claiming failed: ${error.message}`);
  return Array.isArray(data) ? data[0] : data;
}

async function runJob(job) {
  currentJobId = job.id;
  log(`▶ job ${job.id} — submission ${job.submission_id} [${job.formats.join(", ")}] attempt ${job.attempts}`);

  const beat = setInterval(() => {
    supabase
      .from("render_jobs")
      .update({ heartbeat_at: new Date().toISOString() })
      .eq("id", job.id)
      .then(undefined, () => {}); // a missed beat is not fatal; the next one covers it
  }, HEARTBEAT_MS);

  const cleanup = [];
  try {
    const { data: sub, error: subErr } = await supabase
      .from("submissions")
      .select("*")
      .eq("id", job.submission_id)
      .single();
    if (subErr || !sub) throw new Error(`submission not found: ${subErr?.message ?? job.submission_id}`);

    await supabase.from("submissions").update({ status: "in_progress" }).eq("id", sub.id);

    const rendered = await renderFormats({
      supabase,
      sub,
      formats: job.formats,
      start: Number(job.clip_start_seconds),
      duration: Number(job.duration_seconds),
      endCardUrl: env.NEXT_PUBLIC_SITE_URL || "",
      log: (m) => log(`   ${m}`),
    });
    cleanup.push(...rendered.map((r) => r.outFile));

    const urls = await uploadClips(supabase, sub.id, rendered);
    const primary = urls.find((u) => u.format === "vertical") ?? urls[0];

    await supabase
      .from("submissions")
      .update({ sample_clip_url: primary.url, status: "clip_ready" })
      .eq("id", sub.id);

    await supabase
      .from("render_jobs")
      .update({
        status: "done",
        finished_at: new Date().toISOString(),
        clip_urls: urls,
        error: null,
      })
      .eq("id", job.id);

    log(`✔ job ${job.id} done — ${urls.map((u) => u.format).join(", ")}`);
  } catch (e) {
    const message = String(e?.message ?? e).slice(0, 500);
    const exhausted = job.attempts >= job.max_attempts;
    await supabase
      .from("render_jobs")
      .update({
        // Leave it queued while retries remain; claim_render_job picks it up again
        status: exhausted ? "failed" : "queued",
        error: message,
        worker_id: null,
        finished_at: exhausted ? new Date().toISOString() : null,
      })
      .eq("id", job.id);
    // Put the submission back in the queue so it never looks stuck mid-render
    await supabase
      .from("submissions")
      .update({ status: "queued" })
      .eq("id", job.submission_id)
      .eq("status", "in_progress");
    log(`✖ job ${job.id} ${exhausted ? "FAILED permanently" : "failed, will retry"}: ${message}`);
  } finally {
    clearInterval(beat);
    currentJobId = null;
    for (const f of cleanup) rmSync(f, { force: true }); // clips live in storage now
  }
}

log(`worker ${WORKER_ID} started (${ONCE ? "drain once" : `polling every ${POLL_MS}ms`})`);

while (!stopping) {
  let job;
  try {
    job = await claim();
  } catch (e) {
    log(`! ${e.message}`);
    if (ONCE) process.exit(1);
    await new Promise((r) => setTimeout(r, POLL_MS));
    continue;
  }

  if (!job) {
    if (ONCE) {
      log("queue empty — exiting");
      break;
    }
    await new Promise((r) => setTimeout(r, POLL_MS));
    continue;
  }

  await runJob(job);
}
