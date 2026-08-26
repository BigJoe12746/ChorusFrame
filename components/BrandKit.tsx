"use client";

import { useState } from "react";

const FONTS = [
  { id: "", label: "Template default" },
  { id: "sans", label: "Sans" },
  { id: "serif", label: "Serif" },
  { id: "mono", label: "Mono" },
] as const;

/**
 * The artist's saved identity, applied to every render.
 *
 * Belongs to the artist rather than a song — the point is that release five
 * looks like release one without re-choosing anything. Colours set here
 * outrank both the template palette and cover-art extraction.
 */
export default function BrandKit({
  initial,
}: {
  initial: {
    primary: string | null;
    secondary: string | null;
    font: string | null;
  };
}) {
  const [open, setOpen] = useState(false);
  const [primary, setPrimary] = useState(initial.primary ?? "#22dcf5");
  const [secondary, setSecondary] = useState(initial.secondary ?? "#7c3aed");
  const [font, setFont] = useState(initial.font ?? "");
  const [on, setOn] = useState(Boolean(initial.primary || initial.secondary || initial.font));
  const [state, setState] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [error, setError] = useState("");

  async function save(clear = false) {
    setState("saving");
    setError("");
    try {
      const res = await fetch("/api/brand", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(
          clear
            ? { primary: null, secondary: null, font: null }
            : { primary, secondary, font: font || null }
        ),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Could not save");
      setOn(!clear);
      setState("saved");
      setTimeout(() => setState("idle"), 2500);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save");
      setState("error");
    }
  }

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="glow-hover flex items-center gap-2 rounded-lg border border-borderline px-3 py-1.5 text-xs text-muted transition hover:border-cyan hover:text-foreground"
      >
        {on ? (
          <>
            <span
              aria-hidden
              className="h-3 w-3 rounded-full"
              style={{ background: `linear-gradient(135deg, ${primary}, ${secondary})` }}
            />
            Brand kit
          </>
        ) : (
          "Set up your brand kit"
        )}
      </button>
    );
  }

  return (
    <div className="w-full rounded-xl border border-borderline bg-surface p-4">
      <div className="mb-1 flex items-baseline justify-between">
        <p className="text-sm font-semibold">Brand kit</p>
        <button
          onClick={() => setOpen(false)}
          className="text-xs text-muted transition hover:text-foreground"
        >
          Close
        </button>
      </div>
      <p className="mb-4 text-xs text-muted">
        Applied to every render, on top of whichever template you pick — so your
        releases look like a set.
      </p>

      <div className="flex flex-wrap items-end gap-5">
        <div>
          <label htmlFor="brand-primary" className="mb-1.5 block text-xs font-medium">
            Accent
          </label>
          <div className="flex items-center gap-2">
            <input
              id="brand-primary"
              type="color"
              value={primary}
              onChange={(e) => setPrimary(e.target.value)}
              className="h-9 w-12 cursor-pointer rounded border border-borderline bg-surface-raised"
            />
            <code className="text-[11px] text-muted">{primary}</code>
          </div>
        </div>

        <div>
          <label htmlFor="brand-secondary" className="mb-1.5 block text-xs font-medium">
            Secondary
          </label>
          <div className="flex items-center gap-2">
            <input
              id="brand-secondary"
              type="color"
              value={secondary}
              onChange={(e) => setSecondary(e.target.value)}
              className="h-9 w-12 cursor-pointer rounded border border-borderline bg-surface-raised"
            />
            <code className="text-[11px] text-muted">{secondary}</code>
          </div>
        </div>

        <div>
          <label htmlFor="brand-font" className="mb-1.5 block text-xs font-medium">
            Type
          </label>
          <select
            id="brand-font"
            value={font}
            onChange={(e) => setFont(e.target.value)}
            className="h-9 rounded-lg border border-borderline bg-surface-raised px-2 text-xs focus:border-cyan focus:outline-none"
          >
            {FONTS.map((f) => (
              <option key={f.id} value={f.id}>
                {f.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {error ? <p className="mt-3 text-xs text-danger">{error}</p> : null}

      <div className="mt-4 flex items-center gap-2">
        <button
          onClick={() => save(false)}
          disabled={state === "saving"}
          className="glow-hover-strong brand-gradient rounded-lg px-4 py-1.5 text-xs font-semibold text-white transition hover:opacity-90 disabled:opacity-60"
        >
          {state === "saving" ? "Saving…" : "Save brand kit"}
        </button>
        {on ? (
          <button
            onClick={() => save(true)}
            className="rounded-lg px-2 py-1.5 text-xs text-muted transition hover:text-foreground"
          >
            Use template colours instead
          </button>
        ) : null}
        {state === "saved" ? (
          <span className="text-xs text-cyan">Saved — next render uses it.</span>
        ) : null}
      </div>
    </div>
  );
}
