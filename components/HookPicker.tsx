"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { MAX_START } from "@/lib/clip-limits";
import { analyzeAudio, type Analysis } from "@/lib/audio-analysis";

const BUCKETS = 600;

function mmss(seconds: number) {
  const s = Math.max(0, Math.round(seconds));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

/**
 * Choose which part of the song becomes the clip.
 *
 * Without this every clip is the first 15 seconds, which for most tracks is the
 * intro — no vocal, no hook, the least promotable part of the song.
 *
 * The waveform is decoded in the browser from a short-lived signed URL. If that
 * fails for any reason (big file, codec, expired link) the component falls back
 * to a plain numeric start so the artist can still choose a window.
 */
export default function HookPicker({
  submissionId,
  audioUrl,
  start,
  duration,
  onChange,
}: {
  submissionId: string;
  audioUrl: string | null;
  start: number;
  duration: number;
  onChange: (start: number) => void;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const trackRef = useRef<HTMLDivElement>(null);
  const [peaks, setPeaks] = useState<number[] | null>(null);
  const [audioDuration, setAudioDuration] = useState<number | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "failed">("loading");
  const [dragging, setDragging] = useState(false);
  const [analysis, setAnalysis] = useState<Analysis | null>(null);
  /** Only auto-jump to the suggestion once, so it never fights the artist. */
  const suggested = useRef(false);

  // Decode once per song and reduce to a fixed number of peaks
  useEffect(() => {
    if (!audioUrl) {
      setState("failed");
      return;
    }
    let live = true;
    let ctx: AudioContext | null = null;

    (async () => {
      try {
        const res = await fetch(audioUrl);
        if (!res.ok) throw new Error(String(res.status));
        const buf = await res.arrayBuffer();
        ctx = new AudioContext();
        const audio = await ctx.decodeAudioData(buf);
        if (!live) return;

        const data = audio.getChannelData(0);
        const per = Math.floor(data.length / BUCKETS) || 1;
        const out: number[] = [];
        for (let i = 0; i < BUCKETS; i++) {
          let peak = 0;
          const startIdx = i * per;
          for (let j = 0; j < per; j += 16) {
            const v = Math.abs(data[startIdx + j] ?? 0);
            if (v > peak) peak = v;
          }
          out.push(peak);
        }
        const max = Math.max(...out, 0.0001);
        setPeaks(out.map((p) => p / max));
        setAudioDuration(audio.duration);

        // Same samples, second use: find the loudest sustained stretch and
        // open there. The old default of 0:00 was the intro of most tracks.
        const a = analyzeAudio(data, audio.sampleRate, duration, MAX_START);
        setAnalysis(a);

        // Store the beat grid with the song. The worker has no audio decoder,
        // so this browser-side detection is the only place it can come from.
        // Fire-and-forget: failing to save it costs beat-locked motion, not
        // the render.
        if (a.beatGrid) {
          fetch("/api/submissions/analysis", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              submissionId,
              bpm: a.beatGrid.bpm,
              beatOffset: a.beatGrid.offset,
            }),
          }).catch(() => {});
        }
        if (!suggested.current && a.bestStart > 0) {
          suggested.current = true;
          onChange(a.bestStart);
        }
        setState("ready");
      } catch {
        if (live) setState("failed");
      } finally {
        ctx?.close().catch(() => {});
      }
    })();

    return () => {
      live = false;
    };
    // Intentionally keyed on the URL alone. Adding `duration` or `onChange`
    // would re-run the decode — a second download of the whole song — every
    // time the artist changed clip length. The suggestion is computed once
    // from the length in effect at decode time, which is what we want.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [audioUrl]);

  // Draw the waveform whenever the peaks or the chosen window change.
  // Also redraws on resize: a canvas sized while the element has no layout
  // (opened in a hidden panel, or the window resized afterwards) would
  // otherwise stay blank forever, since nothing else re-triggers the draw.
  const [drawTick, setDrawTick] = useState(0);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || typeof ResizeObserver === "undefined") return;
    const ro = new ResizeObserver(() => setDrawTick((t) => t + 1));
    ro.observe(canvas);
    return () => ro.disconnect();
  }, [peaks]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !peaks || !audioDuration) return;
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (w === 0 || h === 0) return; // no layout yet; the observer will call us back
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, w, h);

    const selFrom = (start / audioDuration) * w;
    const selTo = ((start + duration) / audioDuration) * w;
    const barW = w / peaks.length;

    peaks.forEach((p, i) => {
      const x = i * barW;
      const inside = x >= selFrom - barW && x <= selTo;
      const bh = Math.max(1.5, p * (h - 6));
      ctx.fillStyle = inside ? "#22dcf5" : "#2b3355";
      ctx.fillRect(x, (h - bh) / 2, Math.max(1, barW - 0.6), bh);
    });
  }, [peaks, audioDuration, start, duration, drawTick]);

  const setFromClientX = useCallback(
    (clientX: number) => {
      const track = trackRef.current;
      if (!track || !audioDuration) return;
      const rect = track.getBoundingClientRect();
      const ratio = (clientX - rect.left) / rect.width;
      // Centre the window on the pointer, then keep it inside the song
      const raw = ratio * audioDuration - duration / 2;
      const max = Math.min(MAX_START, Math.max(0, audioDuration - duration));
      onChange(Math.min(max, Math.max(0, Math.round(raw * 10) / 10)));
    },
    [audioDuration, duration, onChange]
  );

  useEffect(() => {
    if (!dragging) return;
    const move = (e: PointerEvent) => setFromClientX(e.clientX);
    const up = () => setDragging(false);
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
    return () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
    };
  }, [dragging, setFromClientX]);

  // Keep the window inside the song — and inside what the API will accept —
  // when the artist changes clip length
  useEffect(() => {
    if (!audioDuration) return;
    const max = Math.min(MAX_START, Math.max(0, audioDuration - duration));
    if (start > max) onChange(max);
  }, [duration, audioDuration, start, onChange]);

  if (state === "failed" || !audioDuration) {
    return (
      <div className="rounded-lg border border-borderline bg-surface p-3">
        <label htmlFor="hook-start" className="block text-xs font-medium">
          Start the clip at{" "}
          <span className="font-normal text-muted">
            {state === "loading" ? "(loading waveform…)" : "(seconds into the song)"}
          </span>
        </label>
        <input
          id="hook-start"
          type="number"
          min={0}
          step={1}
          value={start}
          onChange={(e) => onChange(Math.max(0, Number(e.target.value) || 0))}
          className="mt-1.5 w-28 rounded-lg border border-borderline bg-surface-raised px-2 py-1 text-sm focus:border-cyan focus:outline-none"
        />
      </div>
    );
  }

  const pct = (v: number) => `${Math.min(100, (v / audioDuration) * 100)}%`;
  // The API refuses a start past MAX_START, and a 50MB cap is a byte cap: a
  // 192kbps MP3 reaches it around 36 minutes. Without this bound the picker
  // would offer positions that always fail on submit.
  const maxStart = Math.min(MAX_START, Math.max(0, audioDuration - duration));
  const cappedByLimit = audioDuration - duration > MAX_START;
  // The song can be shorter than the requested clip; the render clamps to the
  // audio that exists, so the label should say what will actually be produced
  // rather than promising a window past the end of the track.
  const effectiveEnd = Math.min(start + duration, audioDuration);
  const shortened = effectiveEnd - start < duration - 0.05;

  return (
    <div>
      <div className="mb-1.5 flex flex-wrap items-baseline justify-between gap-x-2 text-xs">
        <span className="font-medium">
          Pick your hook
          {analysis?.tempo ? (
            <span className="ml-1.5 font-normal text-muted">≈{analysis.tempo} BPM</span>
          ) : null}
        </span>
        <span className="text-muted">
          {mmss(start)} – {mmss(effectiveEnd)} of {mmss(audioDuration)}
          {shortened ? (
            <span className="ml-1 text-cyan">
              (song is shorter — {Math.round(effectiveEnd - start)}s clip)
            </span>
          ) : null}
        </span>
      </div>

      <div
        ref={trackRef}
        onPointerDown={(e) => {
          setDragging(true);
          setFromClientX(e.clientX);
        }}
        className="relative h-20 w-full cursor-pointer touch-none overflow-hidden rounded-lg border border-borderline bg-surface"
      >
        <canvas ref={canvasRef} className="h-full w-full" />
        {/* Selected window */}
        <div
          className="pointer-events-none absolute inset-y-0 border-x-2 border-cyan bg-cyan/10"
          style={{ left: pct(start), width: pct(duration) }}
        />
      </div>

      {/* Keyboard path: dragging a canvas is mouse-only, so the window is also
          a real slider that arrow keys can move. */}
      <input
        type="range"
        aria-label="Clip start time in seconds"
        min={0}
        max={Math.round(maxStart)}
        step={1}
        value={Math.min(start, maxStart)}
        onChange={(e) => onChange(Number(e.target.value))}
        className="mt-2 w-full accent-[var(--cyan)]"
      />

      {analysis && Math.abs(analysis.bestStart - start) > 0.6 ? (
        <button
          type="button"
          onClick={() => onChange(Math.min(maxStart, analysis.bestStart))}
          className="mt-2 rounded-lg border border-borderline px-2.5 py-1 text-[11px] text-muted transition hover:border-cyan hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
        >
          ✨ Jump to the strongest part ({mmss(analysis.bestStart)})
        </button>
      ) : null}

      <p className="mt-1 text-[11px] text-muted">
        Drag on the waveform, or use the slider. We start you at the loudest
        sustained stretch — usually the chorus.
        {cappedByLimit ? (
          <span className="ml-1 text-cyan">
            Clips can start up to {mmss(MAX_START)}.
          </span>
        ) : null}
      </p>
    </div>
  );
}
