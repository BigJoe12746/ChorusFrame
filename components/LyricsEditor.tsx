"use client";

import { useState } from "react";

/**
 * Add or fix the words on a song you already uploaded.
 *
 * The lyrics box at upload time is optional and easy to skip, and skipping it
 * silently produces a visualizer rather than a lyric video — with no way back.
 * This is that way back, plus the warning that should have appeared in the
 * first place.
 */
export default function LyricsEditor({
  submissionId,
  initialLyrics,
}: {
  submissionId: string;
  initialLyrics: string;
}) {
  const [lyrics, setLyrics] = useState(initialLyrics);
  const [saved, setSaved] = useState(initialLyrics);
  const [editing, setEditing] = useState(!initialLyrics.trim());
  const [state, setState] = useState<"idle" | "saving" | "error">("idle");
  const [error, setError] = useState("");

  const dirty = lyrics.trim() !== saved.trim();
  const lineCount = saved.split(/\r?\n/).filter((l) => l.trim() && !/^\[.*\]$/.test(l.trim())).length;

  async function save() {
    setState("saving");
    setError("");
    try {
      const res = await fetch("/api/submissions/lyrics", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ submissionId, lyrics }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Could not save");
      setSaved(lyrics);
      setState("idle");
      if (lyrics.trim()) setEditing(false);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save");
      setState("error");
    }
  }

  if (!editing) {
    return (
      <div>
        <div className="mb-1.5 flex items-baseline justify-between">
          <p className="text-xs font-medium">Lyrics</p>
          <button
            onClick={() => setEditing(true)}
            className="text-xs text-cyan underline underline-offset-4"
          >
            Edit
          </button>
        </div>
        <p className="text-[11px] text-muted">
          {lineCount} line{lineCount === 1 ? "" : "s"} saved — these appear on screen.
        </p>
      </div>
    );
  }

  return (
    <div>
      <p className="mb-1.5 text-xs font-medium">Lyrics</p>

      {!saved.trim() ? (
        <p className="mb-2 rounded-lg border border-borderline bg-surface p-2 text-[11px] leading-relaxed text-muted">
          <span className="text-foreground">No lyrics yet.</span> Without them
          you&apos;ll get a visualizer — cover art and waveform, no words. Paste the
          section you want on screen, usually the chorus.
        </p>
      ) : null}

      <textarea
        value={lyrics}
        onChange={(e) => setLyrics(e.target.value)}
        rows={5}
        placeholder={"Paste your chorus here\nOne line per line"}
        className="w-full rounded-lg border border-borderline bg-surface px-3 py-2 text-xs text-foreground placeholder:text-muted focus:border-cyan focus:outline-none focus:ring-2 focus:ring-cyan/40"
      />
      <p className="mt-1 text-[11px] text-muted">
        One line per line. Section markers like [Chorus] are ignored.
      </p>

      {error ? <p className="mt-1 text-[11px] text-danger">{error}</p> : null}

      <div className="mt-2 flex gap-2">
        <button
          onClick={save}
          disabled={state === "saving" || !dirty}
          className="rounded-lg border border-cyan px-3 py-1 text-xs text-foreground transition hover:bg-surface disabled:opacity-50"
        >
          {state === "saving" ? "Saving…" : "Save lyrics"}
        </button>
        {saved.trim() ? (
          <button
            onClick={() => {
              setLyrics(saved);
              setEditing(false);
            }}
            className="rounded-lg px-2 py-1 text-xs text-muted transition hover:text-foreground"
          >
            Cancel
          </button>
        ) : null}
      </div>
    </div>
  );
}
