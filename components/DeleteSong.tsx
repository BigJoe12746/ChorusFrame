"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

/**
 * Delete a song and everything made from it.
 *
 * Two-step by design: this removes the master audio, the artwork and every
 * rendered clip, and none of it comes back. The confirmation says exactly
 * what goes rather than asking "are you sure?", which nobody reads.
 */
export default function DeleteSong({
  submissionId,
  songTitle,
  clipCount,
}: {
  submissionId: string;
  songTitle: string;
  clipCount: number;
}) {
  const router = useRouter();
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function remove() {
    setBusy(true);
    setError("");
    try {
      const res = await fetch("/api/submissions/delete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ submissionId }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Could not delete");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not delete");
      setBusy(false);
      setConfirming(false);
    }
  }

  if (!confirming) {
    return (
      <div className="flex flex-col items-end gap-1">
        <button
          onClick={() => setConfirming(true)}
          className="rounded-lg px-2 py-1 text-xs text-muted transition hover:text-danger"
        >
          Delete
        </button>
        {error ? <p className="text-[11px] text-danger">{error}</p> : null}
      </div>
    );
  }

  return (
    <div className="rounded-lg border border-danger/40 bg-surface p-2.5 text-right">
      <p className="text-[11px] leading-relaxed text-muted">
        Delete <span className="text-foreground">{songTitle}</span>? This removes
        the audio, the artwork
        {clipCount > 0 ? ` and ${clipCount} finished clip${clipCount === 1 ? "" : "s"}` : ""}.
        It can&apos;t be undone.
      </p>
      <div className="mt-2 flex justify-end gap-2">
        <button
          onClick={remove}
          disabled={busy}
          className="rounded-lg bg-danger px-2.5 py-1 text-[11px] font-semibold text-white transition hover:opacity-90 disabled:opacity-60"
        >
          {busy ? "Deleting…" : "Delete for good"}
        </button>
        <button
          onClick={() => setConfirming(false)}
          disabled={busy}
          className="rounded-lg px-2 py-1 text-[11px] text-muted transition hover:text-foreground"
        >
          Keep it
        </button>
      </div>
    </div>
  );
}
