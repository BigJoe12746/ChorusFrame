"use client";

import { useState } from "react";

/**
 * Copy a public link to this song's finished clips.
 *
 * Only rendered once clips exist — a share link to an empty page is worse than
 * no link. The page itself shows the song, the artist and the videos, and
 * deliberately nothing else: no email, no master audio.
 */
export default function ShareLink({ submissionId }: { submissionId: string }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    const url = `${window.location.origin}/c/${submissionId}`;
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2200);
    } catch {
      // Clipboard can be blocked (permissions, insecure context). Opening the
      // page is a worse experience than copying, but better than nothing
      // happening at all.
      window.open(url, "_blank", "noopener");
    }
  }

  return (
    <button
      onClick={copy}
      className="glow-hover rounded-lg bg-surface-raised px-2.5 py-1 text-xs text-muted transition hover:text-foreground"
      title="Public link to these clips"
    >
      {copied ? "Link copied" : "Share"}
    </button>
  );
}
