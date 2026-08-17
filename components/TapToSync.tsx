"use client";

import { useCallback, useEffect, useRef, useState } from "react";

const mmss = (s: number) =>
  `${Math.floor(Math.max(0, s) / 60)}:${String(Math.floor(Math.max(0, s) % 60)).padStart(2, "0")}`;

/** Display lines, ignoring [Chorus]-style section markers. */
function toLines(lyrics: string) {
  return lyrics
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !/^\[.*\]$/.test(l));
}

/**
 * Tap the beat of your own words.
 *
 * Without a transcription key the lines are spread evenly across the clip,
 * which is why they drift off the vocal. Tapping is both the fix and, for sung
 * material, often better than a model: transcribers are unreliable on singing,
 * and the artist knows exactly where their own line lands.
 *
 * Saved as song-absolute seconds — the same shape a transcriber produces — so
 * the render pipeline uses them without knowing where they came from.
 */
export default function TapToSync({
  submissionId,
  audioUrl,
  lyrics,
  startAt,
  onSaved,
}: {
  submissionId: string;
  audioUrl: string | null;
  lyrics: string;
  startAt: number;
  onSaved?: () => void;
}) {
  const lines = toLines(lyrics);
  const audioRef = useRef<HTMLAudioElement>(null);
  const [open, setOpen] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [marks, setMarks] = useState<number[]>([]);
  const [now, setNow] = useState(startAt);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");

  const nextIndex = marks.length;
  const done = nextIndex >= lines.length;

  const tap = useCallback(() => {
    const a = audioRef.current;
    if (!a || done) return;
    setMarks((m) => [...m, a.currentTime]);
  }, [done]);

  // Space is the natural key for this — you're listening, not looking.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.code !== "Space") return;
      const el = e.target as HTMLElement | null;
      if (el && /INPUT|TEXTAREA/.test(el.tagName)) return;
      e.preventDefault();
      tap();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, tap]);

  useEffect(() => {
    const a = audioRef.current;
    if (!a || !open) return;
    const onTime = () => setNow(a.currentTime);
    a.addEventListener("timeupdate", onTime);
    return () => a.removeEventListener("timeupdate", onTime);
  }, [open]);

  function startOver() {
    const a = audioRef.current;
    setMarks([]);
    setSaved(false);
    if (a) {
      a.currentTime = startAt;
      a.play().then(() => setPlaying(true)).catch(() => {});
    }
  }

  function toggle() {
    const a = audioRef.current;
    if (!a) return;
    if (a.paused) {
      if (a.currentTime < startAt) a.currentTime = startAt;
      a.play().then(() => setPlaying(true)).catch(() => {});
    } else {
      a.pause();
      setPlaying(false);
    }
  }

  async function save() {
    setSaving(true);
    setError("");
    try {
      // A line runs until the next one starts; the last gets a sensible tail.
      const timings = marks.map((start, i) => ({
        text: lines[i],
        start,
        end: i + 1 < marks.length ? marks[i + 1] : start + 3,
      }));
      const res = await fetch("/api/submissions/timing", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ submissionId, timings }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Could not save");
      setSaved(true);
      onSaved?.();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save");
    } finally {
      setSaving(false);
    }
  }

  if (!audioUrl || !lines.length) return null;

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="self-start rounded-lg border border-borderline px-3 py-1.5 text-xs font-medium text-muted transition hover:border-cyan hover:text-foreground"
      >
        Sync lyrics to the beat
      </button>
    );
  }

  return (
    <div className="rounded-lg border border-borderline bg-surface p-3">
      <audio ref={audioRef} src={audioUrl} preload="auto" />

      <div className="mb-2 flex items-baseline justify-between">
        <p className="text-xs font-medium">Tap each line as it&apos;s sung</p>
        <span className="font-mono text-[11px] text-muted">{mmss(now)}</span>
      </div>

      <p className="mb-2 text-[11px] leading-relaxed text-muted">
        Press play, then hit <span className="text-foreground">Tap</span> (or the
        spacebar) the moment each line starts. {lines.length} line
        {lines.length === 1 ? "" : "s"} to mark.
      </p>

      {/* The line you're waiting for, and the one after it */}
      <div className="mb-3 rounded-lg bg-surface-raised p-3">
        {done ? (
          <p className="text-sm text-cyan">All {lines.length} lines marked.</p>
        ) : (
          <>
            <p className="text-sm font-semibold text-foreground">{lines[nextIndex]}</p>
            {lines[nextIndex + 1] ? (
              <p className="mt-1 truncate text-xs text-muted">next: {lines[nextIndex + 1]}</p>
            ) : null}
          </>
        )}
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <button
          onClick={toggle}
          className="rounded-lg border border-borderline px-3 py-1.5 text-xs transition hover:border-cyan"
        >
          {playing ? "Pause" : "Play"}
        </button>
        <button
          onClick={tap}
          disabled={done}
          className="brand-gradient rounded-lg px-5 py-1.5 text-xs font-semibold text-white transition hover:opacity-90 disabled:opacity-40"
        >
          Tap
        </button>
        <button
          onClick={startOver}
          className="rounded-lg px-2 py-1.5 text-xs text-muted transition hover:text-foreground"
        >
          Start over
        </button>
        <span className="text-[11px] text-muted">
          {marks.length}/{lines.length}
        </span>
      </div>

      {marks.length > 0 ? (
        <ul className="mt-3 max-h-28 overflow-y-auto text-[11px] text-muted">
          {marks.map((m, i) => (
            <li key={i} className="flex gap-2">
              <span className="font-mono text-cyan">{mmss(m)}</span>
              <span className="truncate">{lines[i]}</span>
            </li>
          ))}
        </ul>
      ) : null}

      {error ? <p className="mt-2 text-[11px] text-danger">{error}</p> : null}
      {saved ? (
        <p className="mt-2 text-[11px] text-cyan">
          Saved — your next render uses these timings.
        </p>
      ) : null}

      <div className="mt-3 flex gap-2">
        <button
          onClick={save}
          disabled={!marks.length || saving}
          className="rounded-lg border border-cyan px-3 py-1 text-xs transition hover:bg-surface-raised disabled:opacity-50"
        >
          {saving ? "Saving…" : `Save timing${marks.length < lines.length ? ` (${marks.length} lines)` : ""}`}
        </button>
        <button
          onClick={() => {
            audioRef.current?.pause();
            setPlaying(false);
            setOpen(false);
          }}
          className="rounded-lg px-2 py-1 text-xs text-muted transition hover:text-foreground"
        >
          Close
        </button>
      </div>
    </div>
  );
}
