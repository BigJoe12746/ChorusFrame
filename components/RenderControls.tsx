"use client";

import { useCallback, useEffect, useState } from "react";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";
import HookPicker from "@/components/HookPicker";
import ClipPreview from "@/components/ClipPreview";
import LyricsEditor from "@/components/LyricsEditor";

export type RenderJob = {
  id: string;
  status: string;
  formats: string[];
  attempts: number;
  max_attempts: number;
  error: string | null;
  clip_urls: { format: string; url: string }[] | null;
};

const FORMAT_LABELS: Record<string, string> = {
  vertical: "9:16 vertical",
  square: "1:1 square",
  wide: "16:9 wide",
};

const ACTIVE = ["queued", "rendering"];

/** Mirrors remotion/vibes.ts. Swatches are indicative, not the render itself. */
const VIBES = [
  { id: "hyperpop", label: "Hyperpop", blurb: "Candy, caps, hard pump", from: "#ff4fd8", to: "#22dcf5" },
  { id: "anime", label: "Dark anime", blurb: "Deep black, blood red", from: "#ff2d46", to: "#1a0308" },
  { id: "dreamy", label: "Dreamy", blurb: "Pastel glow, lowercase", from: "#c9b8ff", to: "#ffc2e2" },
  { id: "cinematic", label: "Cinematic", blurb: "Letterboxed, wide serif", from: "#e8d5b0", to: "#2e6f86" },
  { id: "reggae", label: "Reggae", blurb: "Gold and green, bouncy", from: "#ffc400", to: "#1f9d55" },
  { id: "minimal", label: "Minimal", blurb: "Mono, thin, still", from: "#f5f5f5", to: "#555" },
];

export default function RenderControls({
  submissionId,
  initialJob,
  initialVibe,
  audioUrl,
  artworkUrl,
  songTitle,
  artistName,
  lyrics,
  autoOpen = false,
}: {
  submissionId: string;
  initialJob: RenderJob | null;
  initialVibe: string | null;
  audioUrl: string | null;
  artworkUrl: string | null;
  songTitle: string;
  artistName: string;
  lyrics: string;
  autoOpen?: boolean;
}) {
  const [job, setJob] = useState<RenderJob | null>(initialJob);
  const [vibe, setVibe] = useState(initialVibe || "hyperpop");
  const [clipStart, setClipStart] = useState(0);
  const [clipLength, setClipLength] = useState(15);
  const [picking, setPicking] = useState(autoOpen);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState("");
  /** Status reads keep failing — say so rather than spinning silently. */
  const [stale, setStale] = useState(false);

  const jobId = job?.id ?? null;
  const status = job?.status ?? null;
  const active = status ? ACTIVE.includes(status) : false;

  // Poll only while something is in flight. RLS scopes this to the artist's
  // own jobs, so the browser reads the queue directly.
  //
  // Depends on id and status rather than the whole job object: this effect
  // also *sets* the job, so depending on the object would tear down and
  // rebuild the timer on every single poll.
  useEffect(() => {
    if (!active || !jobId || !authConfigured) return;
    let live = true;
    let timer: ReturnType<typeof setTimeout>;
    let failures = 0;

    const tick = async () => {
      const { data, error: readErr } = await getSupabaseBrowser()
        .from("render_jobs")
        .select("id, status, formats, attempts, max_attempts, error, clip_urls")
        .eq("id", jobId)
        .maybeSingle();
      if (!live) return;

      if (data) {
        failures = 0;
        setStale(false);
        setJob(data as RenderJob);
        if (ACTIVE.includes(data.status)) timer = setTimeout(tick, 3000);
        return;
      }

      // A read can fail for reasons that have nothing to do with the render:
      // the laptop slept, the JWT expired, one request 500'd. Giving up here
      // would leave the row spinning forever while the worker finished the job.
      failures += 1;
      if (readErr) console.warn("[render] status poll failed:", readErr.message);
      if (failures >= 4) setStale(true);
      timer = setTimeout(tick, Math.min(30000, 3000 * 2 ** (failures - 1)));
    };

    timer = setTimeout(tick, 3000);
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [active, jobId]);

  const start = useCallback(async () => {
    setStarting(true);
    setError("");
    try {
      const res = await fetch("/api/render", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          submissionId,
          formats: ["vertical", "square", "wide"],
          clipStartSeconds: clipStart,
          durationSeconds: clipLength,
          vibe,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Could not start the render");
      setJob({
        id: data.id,
        status: "queued",
        formats: ["vertical", "square", "wide"],
        attempts: 0,
        max_attempts: 3,
        error: null,
        clip_urls: null,
      });
      // Without this the panel is still "open" behind the active-job view and
      // springs back the moment the render finishes, remounting the picker and
      // re-downloading the whole song.
      setPicking(false);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not start the render");
      setPicking(false);
    } finally {
      setStarting(false);
    }
  }, [submissionId, vibe, clipStart, clipLength]);

  if (active && job) {
    return (
      <div className="flex flex-col gap-1">
        <div className="flex items-center gap-2 text-xs text-cyan">
          <span className="inline-block h-2 w-2 animate-pulse rounded-full bg-cyan" />
          {job.status === "rendering" ? "Rendering your clips…" : "Queued…"}
          {job.attempts > 1 ? (
            <span className="text-muted">
              (retry {job.attempts} of {job.max_attempts})
            </span>
          ) : null}
        </div>
        {stale ? (
          <p className="text-[11px] text-muted">
            Can&apos;t reach the status right now — still retrying. Your render
            carries on regardless; refresh to check.
          </p>
        ) : null}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      {job?.status === "failed" ? (
        <p className="text-xs text-danger">
          That render didn&apos;t finish{job.error ? `: ${job.error}` : "."} It didn&apos;t
          count against your limit.
        </p>
      ) : null}
      {job?.status === "done" && job.clip_urls?.length ? (
        <div className="flex flex-wrap gap-2">
          {job.clip_urls.map((c) => (
            <a
              key={c.format}
              href={c.url}
              target="_blank"
              rel="noreferrer"
              className="rounded-lg border border-borderline px-2.5 py-1 text-xs text-muted transition hover:border-cyan hover:text-foreground"
            >
              {FORMAT_LABELS[c.format] ?? c.format} ↗
            </a>
          ))}
        </div>
      ) : null}
      {error ? <p className="text-xs text-danger">{error}</p> : null}

      {picking ? (
        <div className="flex flex-col gap-4 rounded-xl border border-borderline bg-surface-raised p-3 sm:flex-row">
          {/* Preview first on wide screens: the point is to see the change,
              not to change it and wonder. */}
          <div className="shrink-0">
            <ClipPreview
              audioUrl={audioUrl}
              artworkUrl={artworkUrl}
              songTitle={songTitle}
              artistName={artistName}
              lyrics={lyrics}
              clipStart={clipStart}
              duration={clipLength}
              vibe={vibe}
            />
          </div>

          <div className="flex min-w-0 flex-1 flex-col gap-4">
          {/* First, because no lyrics means no lyric video — and that was
              silently the case for a real upload. */}
          <LyricsEditor submissionId={submissionId} initialLyrics={lyrics} />

          <HookPicker
            audioUrl={audioUrl}
            start={clipStart}
            duration={clipLength}
            onChange={setClipStart}
          />

          <div>
            <p className="mb-1.5 text-xs font-medium">Clip length</p>
            <div className="flex gap-2">
              {[15, 30, 60].map((secs) => (
                <button
                  key={secs}
                  type="button"
                  onClick={() => setClipLength(secs)}
                  className={`rounded-lg border px-3 py-1 text-xs transition ${
                    clipLength === secs
                      ? "border-cyan text-foreground"
                      : "border-borderline text-muted hover:border-muted"
                  }`}
                >
                  {secs}s
                </button>
              ))}
            </div>
          </div>

          <div>
          <p className="mb-2 text-xs font-medium">Pick a vibe</p>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
            {VIBES.map((v) => (
              <button
                key={v.id}
                onClick={() => setVibe(v.id)}
                className={`flex items-center gap-2 rounded-lg border px-2 py-1.5 text-left transition ${
                  vibe === v.id
                    ? "border-cyan bg-surface"
                    : "border-borderline hover:border-muted"
                }`}
              >
                <span
                  aria-hidden
                  className="h-6 w-6 shrink-0 rounded-md"
                  style={{ background: `linear-gradient(135deg, ${v.from}, ${v.to})` }}
                />
                <span className="min-w-0">
                  <span className="block truncate text-xs font-medium">{v.label}</span>
                  <span className="block truncate text-[10px] text-muted">{v.blurb}</span>
                </span>
              </button>
            ))}
          </div>
          </div>

          <div className="flex gap-2">
            <button
              onClick={start}
              disabled={starting}
              data-render-submit
              className="brand-gradient rounded-lg px-3 py-1.5 text-xs font-semibold text-white transition hover:opacity-90 disabled:opacity-60"
            >
              {starting ? "Starting…" : "Start render"}
            </button>
            <button
              onClick={() => setPicking(false)}
              className="rounded-lg px-2 py-1.5 text-xs text-muted transition hover:text-foreground"
            >
              Cancel
            </button>
          </div>
          </div>
        </div>
      ) : (
        <button
          onClick={() => setPicking(true)}
          className="self-start rounded-lg border border-borderline px-3 py-1.5 text-xs font-medium text-muted transition hover:border-cyan hover:text-foreground"
        >
          {job?.status === "done" || job?.status === "failed"
            ? "Render another vibe"
            : "Make my clips"}
        </button>
      )}
    </div>
  );
}
