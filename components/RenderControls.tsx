"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";
import { MAX_DURATION, MIN_DURATION } from "@/lib/clip-limits";
import HookPicker from "@/components/HookPicker";
import ClipPreview from "@/components/ClipPreview";
import LyricsEditor from "@/components/LyricsEditor";
import TapToSync from "@/components/TapToSync";
import LyricTimingEditor, { type TimedLine } from "@/components/LyricTimingEditor";
import { windowLyrics } from "@/remotion/karaoke";

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
  { id: "poster", label: "Poster", blurb: "Cover fills the screen", from: "#ffffff", to: "#22dcf5" },
  { id: "typographic", label: "Typographic", blurb: "No cover, huge words", from: "#ffffff", to: "#0b0b12" },
  { id: "retro", label: "Retro", blurb: "Warm, faded, VHS-ish", from: "#ffb45e", to: "#ff5a3c" },
  { id: "neon", label: "Neon", blurb: "Black and glow, club", from: "#22dcf5", to: "#a855f7" },
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
  beatGrid,
  savedTimings,
  maxClipSeconds,
  planName,
  allowedVibes,
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
  beatGrid: { bpm: number; offset: number } | null;
  savedTimings: TimedLine[];
  maxClipSeconds: number;
  planName: string;
  /** Vibe ids this artist's plan includes; the rest show locked. */
  allowedVibes: string[];
  autoOpen?: boolean;
}) {
  const [job, setJob] = useState<RenderJob | null>(initialJob);
  // A saved vibe the current plan doesn't include (downgrades, old data) falls
  // back to hyperpop — every plan has it, and the API would refuse it anyway.
  const [vibe, setVibe] = useState(() =>
    initialVibe && allowedVibes.includes(initialVibe) ? initialVibe : "hyperpop"
  );
  const [lockedNote, setLockedNote] = useState("");
  const [clipStart, setClipStart] = useState(0);
  const [clipLength, setClipLength] = useState(15);
  /** Real decoded song length, once HookPicker knows it. */
  const [songSeconds, setSongSeconds] = useState<number | null>(null);
  const [picking, setPicking] = useState(autoOpen);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState("");
  /** Status reads keep failing — say so rather than spinning silently. */
  const [stale, setStale] = useState(false);

  // The render clamps an overlong clip window to the real song length in
  // calculateMetadata; the preview has no such hook, so mirror the clamp here
  // or its tail plays frozen bars over silence.
  const previewLength = useMemo(
    () =>
      songSeconds === null
        ? clipLength
        : Math.max(1, Math.min(clipLength, songSeconds - clipStart)),
    [songSeconds, clipLength, clipStart]
  );

  // Saved timings are song-absolute; the preview needs them clip-relative —
  // the same windowing the worker applies, so preview and export agree.
  const previewTiming = useMemo(
    () => windowLyrics(savedTimings, clipStart, previewLength),
    [savedTimings, clipStart, previewLength]
  );

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
    const ready = job.clip_urls ?? [];
    return (
      <div className="flex flex-col gap-1.5">
        <div className="flex items-center gap-2 text-xs text-cyan">
          <span className="inline-block h-2 w-2 animate-pulse rounded-full bg-cyan" />
          {job.status === "rendering"
            ? ready.length
              ? `Rendering… ${ready.length} of ${job.formats.length} ready`
              : "Rendering your clips…"
            : "Queued…"}
          {job.attempts > 1 ? (
            <span className="text-muted">
              (retry {job.attempts} of {job.max_attempts})
            </span>
          ) : null}
        </div>
        {/* Progressive delivery: grab finished formats while the rest render */}
        {ready.length ? (
          <div className="flex flex-wrap items-center gap-2">
            {ready.map((c) => (
              <a
                key={c.format}
                href={c.url}
                target="_blank"
                rel="noreferrer"
                className="glow-hover rounded-lg border border-borderline px-2.5 py-1 text-xs text-muted transition hover:border-cyan hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
              >
                {FORMAT_LABELS[c.format] ?? c.format} ↗
              </a>
            ))}
            <span className="text-[11px] text-muted">no need to wait for the rest</span>
          </div>
        ) : null}
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
              className="glow-hover rounded-lg border border-borderline px-2.5 py-1 text-xs text-muted transition hover:border-cyan hover:text-foreground"
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
              duration={previewLength}
              vibe={vibe}
              showWatermark={planName !== "Pro"}
              beatGrid={beatGrid}
              lyricTiming={previewTiming}
            />
          </div>

          <div className="flex min-w-0 flex-1 flex-col gap-4">
          {/* First, because no lyrics means no lyric video — and that was
              silently the case for a real upload. */}
          <LyricsEditor submissionId={submissionId} initialLyrics={lyrics} />

          {/* Only useful once there are words to time */}
          {lyrics.trim() ? (
            <TapToSync
              submissionId={submissionId}
              audioUrl={audioUrl}
              lyrics={lyrics}
              startAt={clipStart}
            />
          ) : null}

          {/* Only meaningful once something has been timed */}
          <LyricTimingEditor
            submissionId={submissionId}
            audioUrl={audioUrl}
            initialTimings={savedTimings}
          />

          <HookPicker
            submissionId={submissionId}
            audioUrl={audioUrl}
            start={clipStart}
            duration={clipLength}
            onChange={setClipStart}
            onDuration={setSongSeconds}
          />

          <div>
            <div className="mb-1.5 flex items-baseline justify-between">
              <p className="text-xs font-medium">Clip length</p>
              <span className="font-mono text-[11px] text-cyan">{clipLength}s</span>
            </div>

            {/* Any length, not just the three presets — a hook is however long
                the hook is, and 22s is a perfectly reasonable answer. */}
            <input
              type="range"
              aria-label="Clip length in seconds"
              min={MIN_DURATION}
              max={maxClipSeconds}
              step={1}
              value={Math.min(clipLength, maxClipSeconds)}
              onChange={(e) => setClipLength(Number(e.target.value))}
              className="w-full accent-[var(--cyan)]"
            />

            <div className="mt-1.5 flex items-center gap-2">
              {[15, 30, 60].map((secs) => (
                <button
                  key={secs}
                  type="button"
                  disabled={secs > maxClipSeconds}
                  title={
                    secs > maxClipSeconds
                      ? `${planName} covers clips up to ${maxClipSeconds}s`
                      : `Set the clip to ${secs} seconds`
                  }
                  onClick={() => setClipLength(secs)}
                  className={`rounded-lg border px-2.5 py-0.5 text-[11px] transition ${
                    clipLength === secs
                      ? "border-cyan text-foreground"
                      : "border-borderline text-muted hover:border-muted"
                  } disabled:cursor-not-allowed disabled:opacity-35 disabled:hover:border-borderline`}
                >
                  {secs}s
                </button>
              ))}
              <span className="ml-auto text-[11px] text-muted">
                {MIN_DURATION}–{maxClipSeconds}s
                {maxClipSeconds < MAX_DURATION ? ` on ${planName}` : ""}
              </span>
            </div>
          </div>

          <div>
            <div className="mb-2 flex items-baseline justify-between gap-3">
              <p className="text-xs font-medium">Pick a vibe</p>
              {/* One description for the current choice, rather than ten
                  truncated ones nobody can read */}
              <p className="truncate text-[11px] text-muted">
                {VIBES.find((v) => v.id === vibe)?.blurb}
              </p>
            </div>

            <div className="grid grid-cols-3 gap-2 sm:grid-cols-5">
              {VIBES.map((v) => {
                const on = vibe === v.id;
                const locked = !allowedVibes.includes(v.id);
                return (
                  <button
                    key={v.id}
                    type="button"
                    onClick={() =>
                      locked
                        ? setLockedNote(`${v.label} is on Pro — all 10 templates, 60-second clips, no watermark.`)
                        : (setVibe(v.id), setLockedNote(""))
                    }
                    title={locked ? `${v.label} — on Pro` : `${v.label} — ${v.blurb}`}
                    aria-pressed={on}
                    className="group relative flex flex-col items-center gap-1 rounded-lg p-1 transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
                  >
                    {/* A 9:16 chip, so the swatch reads as a clip rather than a colour */}
                    <span
                      aria-hidden
                      className={`block h-12 w-full rounded-md border-2 transition ${
                        on ? "border-cyan" : "border-transparent group-hover:border-muted"
                      } ${locked ? "opacity-40" : ""}`}
                      style={{ background: `linear-gradient(150deg, ${v.from}, ${v.to})` }}
                    />
                    {locked ? (
                      <span className="absolute right-1.5 top-1.5 rounded bg-black/60 px-1 text-[9px] font-semibold uppercase tracking-wide text-cyan">
                        Pro
                      </span>
                    ) : null}
                    <span
                      className={`w-full text-center text-[11px] leading-tight ${
                        on ? "font-semibold text-foreground" : "text-muted"
                      }`}
                    >
                      {v.label}
                    </span>
                  </button>
                );
              })}
            </div>
            {lockedNote ? (
              <p className="mt-2 text-[11px] text-muted">
                {lockedNote}{" "}
                <a href="/dashboard/billing" className="text-cyan underline underline-offset-2">
                  Go Pro
                </a>
              </p>
            ) : null}
          </div>

          <div className="flex gap-2">
            <button
              onClick={start}
              disabled={starting}
              data-render-submit
              className="glow-hover-strong brand-gradient rounded-lg px-3 py-1.5 text-xs font-semibold text-white transition hover:opacity-90 disabled:opacity-60"
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
          className="glow-hover self-start rounded-lg border border-borderline px-3 py-1.5 text-xs font-medium text-muted transition hover:border-cyan hover:text-foreground"
        >
          {job?.status === "done" || job?.status === "failed"
            ? "Render another vibe"
            : "Make my clips"}
        </button>
      )}
    </div>
  );
}
