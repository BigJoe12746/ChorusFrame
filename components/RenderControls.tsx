"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";

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

export default function RenderControls({
  submissionId,
  initialJob,
}: {
  submissionId: string;
  initialJob: RenderJob | null;
}) {
  const [job, setJob] = useState<RenderJob | null>(initialJob);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState("");
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const active = job ? ACTIVE.includes(job.status) : false;

  // Poll only while something is in flight. RLS scopes this to the artist's
  // own jobs, so the browser can read the queue directly.
  useEffect(() => {
    if (!active || !authConfigured) return;
    let live = true;

    const tick = async () => {
      const { data } = await getSupabaseBrowser()
        .from("render_jobs")
        .select("id, status, formats, attempts, max_attempts, error, clip_urls")
        .eq("id", job!.id)
        .maybeSingle();
      if (!live) return;
      if (data) setJob(data as RenderJob);
      if (live && data && ACTIVE.includes(data.status)) {
        timer.current = setTimeout(tick, 3000);
      } else if (live && data?.status === "done") {
        // Clip links live on the server-rendered row; refresh once to pick them up
        window.location.reload();
      }
    };

    timer.current = setTimeout(tick, 3000);
    return () => {
      live = false;
      if (timer.current) clearTimeout(timer.current);
    };
  }, [active, job]);

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
          durationSeconds: 15,
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
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not start the render");
    } finally {
      setStarting(false);
    }
  }, [submissionId]);

  if (active) {
    const label = job!.status === "rendering" ? "Rendering your clips…" : "Queued…";
    return (
      <div className="flex items-center gap-2 text-xs text-cyan">
        <span className="inline-block h-2 w-2 animate-pulse rounded-full bg-cyan" />
        {label}
        {job!.attempts > 1 ? (
          <span className="text-muted">(retry {job!.attempts} of {job!.max_attempts})</span>
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
      <button
        onClick={start}
        disabled={starting}
        className="self-start rounded-lg border border-borderline px-3 py-1.5 text-xs font-medium text-muted transition hover:border-cyan hover:text-foreground disabled:opacity-60"
      >
        {starting
          ? "Starting…"
          : job?.status === "done" || job?.status === "failed"
            ? "Render again"
            : "Make my clips"}
      </button>
    </div>
  );
}
