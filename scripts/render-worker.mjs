// ChorusFrame render worker.
//
//   npm run worker            # poll forever
//   npm run worker:once       # drain the queue and exit
//
// Claims queued jobs one at a time, renders every requested format, uploads
// them, and marks the job done. A crash mid-render leaves a stale heartbeat,
// and claim_render_job() requeues that job for another worker.
//
// Runs anywhere Node + Chrome can: a laptop today, a container later. Nothing
// in the web app knows or cares where this process lives.
//
// Ownership rules this worker follows:
//   * render_jobs.status is the render lifecycle; submissions.status is the
//     delivery lifecycle. This worker only ever advances a submission to
//     clip_ready on success — it never demotes one.
//   * Every terminal write is fenced on (worker_id, attempts), so a worker
//     whose job was reclaimed cannot clobber the new owner's state.

import os from "node:os";
import { rmSync } from "node:fs";
import { loadEnv, makeClient, renderFormats, uploadClips } from "./lib/render.mjs";

const argv = process.argv.slice(2);
const ONCE = argv.includes("--once");
const pollIdx = argv.indexOf("--poll");
const pollArg = pollIdx >= 0 ? Number(argv[pollIdx + 1]) : NaN;
const POLL_MS = Number.isFinite(pollArg) && pollArg > 0 ? pollArg : 5000;
const HEARTBEAT_MS = 30_000;

const WORKER_ID = `${os.hostname()}-${process.pid}`;
const env = loadEnv();
const supabase = makeClient(env);

const log = (...a) => console.log(new Date().toISOString(), ...a);

let stopping = false;
let lease = null; // { id, attempts } — the claim this worker currently holds

/** Terminal writes only land if we still hold the lease we were given. */
async function writeFenced(patch) {
  if (!lease) return false;
  const { data, error } = await supabase
    .from("render_jobs")
    .update(patch)
    .eq("id", lease.id)
    .eq("worker_id", WORKER_ID)
    .eq("attempts", lease.attempts)
    .select("id");
  if (error) {
    log(`! write failed: ${error.message}`);
    return false;
  }
  if (!data?.length) {
    log(`! lease lost on job ${lease.id} — another worker owns it now; discarding result`);
    return false;
  }
  return true;
}

async function releaseLease(reason) {
  if (!lease) return;
  const held = lease;
  await writeFenced({ status: "queued", worker_id: null, error: reason });
  lease = null;
  log(`↩ released job ${held.id}: ${reason}`);
}

for (const sig of ["SIGINT", "SIGTERM"]) {
  process.on(sig, () => {
    if (stopping) process.exit(130);
    stopping = true;
    log(`${sig} received — releasing current job…`);
    releaseLease("worker shut down").finally(() => process.exit(130));
  });
}

async function claim() {
  const { data, error } = await supabase.rpc("claim_render_job", { p_worker: WORKER_ID });
  if (error) throw new Error(`claiming failed: ${error.message}`);
  return Array.isArray(data) ? data[0] : data;
}

async function runJob(job) {
  lease = { id: job.id, attempts: job.attempts };
  log(`▶ job ${job.id} — submission ${job.submission_id} [${job.formats.join(", ")}] attempt ${job.attempts}/${job.max_attempts}`);

  const beat = setInterval(() => {
    // Fenced too: a stale worker must not keep a reclaimed job looking alive
    supabase
      .from("render_jobs")
      .update({ heartbeat_at: new Date().toISOString() })
      .eq("id", job.id)
      .eq("worker_id", WORKER_ID)
      .eq("attempts", job.attempts)
      .then(undefined, () => {}); // a missed beat is covered by the next one
  }, HEARTBEAT_MS);

  const artifacts = [];
  try {
    const { data: sub, error: subErr } = await supabase
      .from("submissions")
      .select("*")
      .eq("id", job.submission_id)
      .maybeSingle();
    if (subErr) throw new Error(`loading submission failed: ${subErr.message}`);
    if (!sub) throw new Error("submission no longer exists");

    // The manual CLI takes a submission-level lock. Respect it rather than
    // rendering the same song twice with different windows.
    if (sub.status === "in_progress") {
      clearInterval(beat);
      await releaseLease("submission is being rendered manually; will retry");
      return;
    }

    const rendered = await renderFormats({
      supabase,
      sub,
      formats: job.formats,
      start: Number(job.clip_start_seconds),
      duration: Number(job.duration_seconds),
      endCardUrl: env.NEXT_PUBLIC_SITE_URL || "",
      env,
      log: (m) => log(`   ${m}`),
    });
    artifacts.push(...rendered.map((r) => r.outFile));

    const urls = await uploadClips(supabase, sub.id, rendered);
    const primary = urls.find((u) => u.format === "vertical") ?? urls[0];

    // Only write the job's terminal state if we still hold the lease.
    const kept = await writeFenced({
      status: "done",
      finished_at: new Date().toISOString(),
      clip_urls: urls,
      error: null,
    });

    if (kept) {
      // Advance delivery state only on success, and never downgrade a
      // submission that has already been delivered.
      await supabase
        .from("submissions")
        .update({ sample_clip_url: primary.url, status: "clip_ready" })
        .eq("id", sub.id)
        .neq("status", "delivered");
      log(`✔ job ${job.id} done — ${urls.map((u) => u.format).join(", ")}`);
    }
    lease = null;
  } catch (e) {
    const message = String(e?.message ?? e).slice(0, 500);
    const exhausted = job.attempts >= job.max_attempts;
    await writeFenced({
      // Leave it queued while retries remain; claim_render_job picks it up again
      status: exhausted ? "failed" : "queued",
      error: message,
      worker_id: null,
      finished_at: exhausted ? new Date().toISOString() : null,
    });
    lease = null;
    log(`✖ job ${job.id} ${exhausted ? "FAILED permanently" : "failed, will retry"}: ${message}`);
  } finally {
    clearInterval(beat);
    lease = null;
    for (const f of artifacts) rmSync(f, { force: true }); // clips live in storage now
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
