"use client";

import { useEffect, useMemo, useRef, useState } from "react";

export type TimedLine = { text: string; start: number; end: number };

function stamp(s: number) {
  const v = Math.max(0, s);
  const m = Math.floor(v / 60);
  const sec = String(Math.floor(v % 60)).padStart(2, "0");
  const tenth = Math.floor((v % 1) * 10);
  return `${m}:${sec}.${tenth}`;
}

/**
 * Correct lyric timings after tapping them.
 *
 * Tapping gets the shape right but runs systematically late — human reaction
 * time is 150–250ms and it applies to every tap. So the control that matters
 * most here is the global shift, which fixes a whole take at once; per-line
 * nudges are for the odd line that drifted.
 *
 * Editing the words themselves stays in the text box. This is only about when
 * they appear.
 */
export default function LyricTimingEditor({
  submissionId,
  audioUrl,
  initialTimings,
}: {
  submissionId: string;
  audioUrl: string | null;
  initialTimings: TimedLine[];
}) {
  const [open, setOpen] = useState(false);
  const [lines, setLines] = useState<TimedLine[]>(initialTimings);
  const [shift, setShift] = useState(0);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");
  const [playing, setPlaying] = useState<number | null>(null);
  const audioRef = useRef<HTMLAudioElement>(null);

  useEffect(() => setLines(initialTimings), [initialTimings]);

  /** What will actually be saved: per-line edits plus the global shift. */
  const shifted = useMemo(
    () =>
      lines.map((l) => ({
        text: l.text,
        start: Math.max(0, l.start + shift),
        end: Math.max(0.1, l.end + shift),
      })),
    [lines, shift]
  );

  const dirty = shift !== 0 || lines !== initialTimings;

  function nudge(i: number, delta: number) {
    setLines((prev) =>
      prev.map((l, j) =>
        j === i
          ? { ...l, start: Math.max(0, l.start + delta), end: Math.max(0.1, l.end + delta) }
          : l
      )
    );
  }

  /** Play a line so you can hear whether it lands where you think. */
  function audition(i: number) {
    const a = audioRef.current;
    if (!a) return;
    a.currentTime = Math.max(0, shifted[i].start - 0.4);
    a.play()
      .then(() => setPlaying(i))
      .catch(() => {});
    const stopAt = shifted[i].end + 0.3;
    const tick = () => {
      const el = audioRef.current;
      if (!el || el.paused) return;
      if (el.currentTime >= stopAt) {
        el.pause();
        setPlaying(null);
      } else requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }

  async function save() {
    setSaving(true);
    setError("");
    try {
      const res = await fetch("/api/submissions/timing", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ submissionId, timings: shifted }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Could not save");
      setLines(shifted);
      setShift(0);
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save");
    } finally {
      setSaving(false);
    }
  }

  if (!initialTimings.length) return null;

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="glow-hover self-start rounded-lg border border-borderline px-3 py-1.5 text-xs font-medium text-muted transition hover:border-cyan hover:text-foreground"
      >
        Adjust lyric timing ({initialTimings.length} lines)
      </button>
    );
  }

  return (
    <div className="rounded-lg border border-borderline bg-surface p-3">
      {audioUrl ? <audio ref={audioRef} src={audioUrl} preload="metadata" /> : null}

      <div className="mb-2 flex items-baseline justify-between">
        <p className="text-xs font-medium">Adjust timing</p>
        <button
          onClick={() => setOpen(false)}
          className="text-xs text-muted transition hover:text-foreground"
        >
          Close
        </button>
      </div>

      {/* The control that matters: taps are late by a consistent amount */}
      <div className="mb-3 rounded-lg bg-surface-raised p-3">
        <div className="flex items-baseline justify-between">
          <p className="text-xs font-medium">Shift every line</p>
          <span className="font-mono text-[11px] text-cyan">
            {shift > 0 ? "+" : ""}
            {shift.toFixed(1)}s
          </span>
        </div>
        <p className="mt-1 text-[11px] leading-relaxed text-muted">
          Tapping runs late by about a fifth of a second, every time. If the
          words feel a beat behind, pull them all earlier.
        </p>
        <div className="mt-2 flex flex-wrap items-center gap-1.5">
          {[-0.5, -0.2, -0.1].map((d) => (
            <button
              key={d}
              onClick={() => setShift((s) => Math.round((s + d) * 10) / 10)}
              className="rounded-lg border border-borderline px-2 py-1 text-[11px] transition hover:border-cyan"
            >
              {d}s
            </button>
          ))}
          <button
            onClick={() => setShift(0)}
            className="rounded-lg px-2 py-1 text-[11px] text-muted transition hover:text-foreground"
          >
            reset
          </button>
          {[0.1, 0.2, 0.5].map((d) => (
            <button
              key={d}
              onClick={() => setShift((s) => Math.round((s + d) * 10) / 10)}
              className="rounded-lg border border-borderline px-2 py-1 text-[11px] transition hover:border-cyan"
            >
              +{d}s
            </button>
          ))}
        </div>
      </div>

      <ul className="max-h-56 overflow-y-auto">
        {shifted.map((l, i) => (
          <li
            key={i}
            className={`flex items-center gap-2 rounded-lg px-1.5 py-1 ${
              playing === i ? "bg-surface-raised" : ""
            }`}
          >
            <button
              onClick={() => audition(i)}
              title="Hear this line"
              className="shrink-0 font-mono text-[11px] text-cyan underline underline-offset-2"
            >
              {stamp(l.start)}
            </button>
            <span className="min-w-0 flex-1 truncate text-[11px]">{l.text}</span>
            <span className="flex shrink-0 gap-1">
              <button
                onClick={() => nudge(i, -0.1)}
                aria-label={`Move line ${i + 1} earlier`}
                className="rounded border border-borderline px-1.5 text-[11px] text-muted transition hover:border-cyan hover:text-foreground"
              >
                −
              </button>
              <button
                onClick={() => nudge(i, 0.1)}
                aria-label={`Move line ${i + 1} later`}
                className="rounded border border-borderline px-1.5 text-[11px] text-muted transition hover:border-cyan hover:text-foreground"
              >
                +
              </button>
            </span>
          </li>
        ))}
      </ul>

      {error ? <p className="mt-2 text-[11px] text-danger">{error}</p> : null}
      {saved ? <p className="mt-2 text-[11px] text-cyan">Saved.</p> : null}

      <div className="mt-3 flex gap-2">
        <button
          onClick={save}
          disabled={saving || !dirty}
          className="rounded-lg border border-cyan px-3 py-1 text-xs transition hover:bg-surface-raised disabled:opacity-50"
        >
          {saving ? "Saving…" : "Save timing"}
        </button>
        <button
          onClick={() => {
            setLines(initialTimings);
            setShift(0);
          }}
          disabled={!dirty}
          className="rounded-lg px-2 py-1 text-xs text-muted transition hover:text-foreground disabled:opacity-40"
        >
          Undo changes
        </button>
      </div>
    </div>
  );
}
