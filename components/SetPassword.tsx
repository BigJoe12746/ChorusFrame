"use client";

import { useState } from "react";
import { authConfigured, getSupabaseBrowser } from "@/lib/supabase-browser";

const MIN_LENGTH = 8;

/**
 * Set (or change) a password so signing in doesn't require the inbox.
 *
 * Magic links are the right default for an artist signing up once, and the
 * wrong default for anyone who uses the product regularly.
 */
export default function SetPassword({ hasPassword }: { hasPassword: boolean }) {
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState("");
  const [state, setState] = useState<"idle" | "saving" | "done" | "error">("idle");
  const [error, setError] = useState("");

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (value.length < MIN_LENGTH) {
      setError(`Use at least ${MIN_LENGTH} characters.`);
      setState("error");
      return;
    }
    setState("saving");
    setError("");
    const { error: err } = await getSupabaseBrowser().auth.updateUser({ password: value });
    if (err) {
      setError(err.message);
      setState("error");
      return;
    }
    setValue("");
    setState("done");
    setOpen(false);
  }

  if (!authConfigured) return null;

  if (state === "done" && !open) {
    return (
      <p className="text-xs text-cyan">
        Password saved — you can log in with it from now on.
      </p>
    );
  }

  if (!open) {
    return (
      <button
        onClick={() => {
          setOpen(true);
          setState("idle");
        }}
        className="text-xs text-muted underline underline-offset-4 transition hover:text-foreground"
      >
        {hasPassword ? "Change your password" : "Set a password (skip the email next time)"}
      </button>
    );
  }

  return (
    <form onSubmit={save} className="flex flex-col gap-2 sm:flex-row sm:items-start">
      <div className="flex-1">
        <label htmlFor="new-password" className="sr-only">
          New password
        </label>
        <input
          id="new-password"
          type="password"
          autoComplete="new-password"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder={`New password (${MIN_LENGTH}+ characters)`}
          className="w-full rounded-lg border border-borderline bg-surface px-3 py-2 text-sm text-foreground placeholder:text-muted focus:border-cyan focus:outline-none focus:ring-2 focus:ring-cyan/40"
        />
        {error ? (
          <p role="alert" className="mt-1 text-xs text-danger">
            {error}
          </p>
        ) : null}
      </div>
      <div className="flex gap-2">
        <button
          type="submit"
          disabled={state === "saving"}
          className="rounded-lg border border-borderline px-3 py-2 text-xs font-medium transition hover:border-cyan disabled:opacity-60"
        >
          {state === "saving" ? "Saving…" : "Save"}
        </button>
        <button
          type="button"
          onClick={() => {
            setOpen(false);
            setValue("");
            setError("");
          }}
          className="rounded-lg px-2 py-2 text-xs text-muted transition hover:text-foreground"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}
