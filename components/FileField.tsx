"use client";

import { useId, useRef, useState } from "react";

function humanSize(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function FileField({
  name,
  label,
  hint,
  accept,
  acceptTypes,
  maxBytes,
  required = false,
  icon,
}: {
  name: string;
  label: string;
  hint: string;
  accept: string;
  /** MIME types to accept; empty type (some browsers) is allowed through. */
  acceptTypes: string[];
  maxBytes: number;
  required?: boolean;
  icon: string;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const id = useId();
  const [file, setFile] = useState<File | null>(null);
  const [error, setError] = useState("");
  const [dragging, setDragging] = useState(false);
  // Focus is tracked in state rather than left to a focus-within variant. The
  // input is visually hidden, so its focus ring is the only thing telling a
  // keyboard user where they are — worth making explicit and testable rather
  // than depending on variant ordering.
  const [focused, setFocused] = useState(false);

  /** Reject oversized or wrong-typed files immediately — not after a long upload. */
  function accepted(f: File) {
    if (f.size > maxBytes) {
      setError(`That file is ${humanSize(f.size)}. The limit is ${humanSize(maxBytes)}.`);
      return false;
    }
    if (f.type && !acceptTypes.includes(f.type)) {
      setError(`${f.type || "That file type"} isn't supported here.`);
      return false;
    }
    setError("");
    return true;
  }

  function choose(f: File | null) {
    if (!f) {
      setFile(null);
      setError("");
      return;
    }
    if (accepted(f)) setFile(f);
    else {
      setFile(null);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  function onDrop(e: React.DragEvent) {
    e.preventDefault();
    setDragging(false);
    const f = e.dataTransfer.files?.[0];
    if (!f) return;
    // Put the dropped file on the real input so the form still submits it
    const dt = new DataTransfer();
    dt.items.add(f);
    if (inputRef.current) inputRef.current.files = dt.files;
    choose(f);
  }

  function clear() {
    if (inputRef.current) inputRef.current.value = "";
    choose(null);
    inputRef.current?.focus();
  }

  return (
    <div>
      <label htmlFor={id} className="mb-1.5 block text-sm font-medium">
        {label} <span className="font-normal text-muted">{hint}</span>
      </label>

      <div
        onDragOver={(e) => {
          e.preventDefault();
          setDragging(true);
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={onDrop}
        style={
          focused
            ? { borderColor: "var(--cyan)", boxShadow: "0 0 0 3px rgba(34,220,245,0.35)" }
            : undefined
        }
        className={`relative rounded-xl border border-dashed transition focus-within:border-cyan ${
          error
            ? "border-danger"
            : dragging
              ? "border-cyan bg-surface-raised"
              : file
                ? "border-borderline bg-surface"
                : "border-borderline bg-surface hover:border-muted"
        }`}
      >
        {/* Visually hidden, but still focusable and in the tab order — `hidden`
            would remove it from keyboard navigation entirely. */}
        <input
          ref={inputRef}
          id={id}
          name={name}
          type="file"
          required={required}
          accept={accept}
          onChange={(e) => choose(e.target.files?.[0] ?? null)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          className="absolute h-px w-px overflow-hidden opacity-0"
        />

        {file ? (
          <div className="flex items-center gap-3 px-4 py-3">
            <span className="text-xl" aria-hidden>
              {icon}
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm text-foreground">{file.name}</span>
              <span className="block text-xs text-muted">{humanSize(file.size)}</span>
            </span>
            <button
              type="button"
              onClick={clear}
              className="rounded-lg border border-borderline px-2.5 py-1 text-xs text-muted transition hover:border-cyan hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
            >
              Remove
            </button>
          </div>
        ) : (
          <label
            htmlFor={id}
            className="flex cursor-pointer items-center justify-center gap-2 px-4 py-6 text-center text-sm text-muted"
          >
            <span className="text-lg" aria-hidden>
              {icon}
            </span>
            <span>
              <span className="text-foreground underline underline-offset-4">Choose a file</span>{" "}
              or drag it here
            </span>
          </label>
        )}
      </div>

      {error ? (
        <p role="alert" className="mt-1.5 text-xs text-danger">
          {error}
        </p>
      ) : null}
    </div>
  );
}
