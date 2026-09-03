"use client";

import { Player } from "@remotion/player";
import { useMemo, useState } from "react";
import { SampleClip, FPS, END_CARD_SECONDS } from "@/remotion/SampleClip";
import { CanvasLoop, CANVAS_SECONDS } from "@/remotion/CanvasLoop";

/**
 * Live preview of the clip, in the browser.
 *
 * This mounts the SAME component the worker renders — not a mock-up — so
 * "the preview matches the export" is true by construction rather than by
 * effort. That promise only holds if the preview shows what is actually being
 * rendered, so it follows every real choice: the formats the artist ticked,
 * their brand kit when their plan applies it, and their plan's end card and
 * watermark. Anything the preview quietly differs on is a promise broken at
 * the moment an export is spent.
 */

/** The canvas each format renders at — the sizes remotion/Root.tsx registers. */
const SIZES: Record<string, { w: number; h: number; label: string }> = {
  vertical: { w: 1080, h: 1920, label: "9:16" },
  square: { w: 1080, h: 1080, label: "1:1" },
  wide: { w: 1920, h: 1080, label: "16:9" },
  canvas: { w: 1080, h: 1920, label: "Canvas" },
};

export default function ClipPreview({
  audioUrl,
  artworkUrl,
  songTitle,
  artistName,
  lyrics,
  clipStart,
  duration,
  vibe,
  beatGrid,
  lyricTiming,
  brand = null,
  showWatermark = true,
  showEndCard = true,
  formats = ["vertical"],
}: {
  audioUrl: string | null;
  artworkUrl: string | null;
  songTitle: string;
  artistName: string;
  lyrics: string;
  clipStart: number;
  duration: number;
  vibe: string;
  beatGrid: { bpm: number; offset: number } | null;
  lyricTiming: { text: string; start: number; end: number }[];
  /**
   * The artist's saved identity — but only when their plan actually applies it
   * on render. Showing brand colours a Free export won't have would be the
   * same broken promise pointed the other way.
   */
  brand?: { primary: string | null; secondary: string | null; font: string | null } | null;
  /** Pro previews without the watermark, matching Pro exports. */
  showWatermark?: boolean;
  /** Free renders carry the 2.6s end card; Pro renders don't. */
  showEndCard?: boolean;
  /** Formats this render will produce — the toggle offers exactly these. */
  formats?: string[];
}) {
  // Preview whichever format is actually being rendered. Defaulting to the
  // first selected one means the panel opens showing something real.
  const [shown, setShown] = useState<string>(formats[0] ?? "vertical");
  const active = formats.includes(shown) ? shown : formats[0] ?? "vertical";
  const size = SIZES[active] ?? SIZES.vertical;
  const isCanvas = active === "canvas";

  const inputProps = useMemo(
    () =>
      isCanvas
        ? // The loop takes no audio and no clip window — it is built from the
          // artwork and the tempo alone.
          { artworkSrc: artworkUrl, songTitle, vibe, brand, beatGrid }
        : {
            audioSrc: audioUrl ?? "",
            artworkSrc: artworkUrl,
            songTitle,
            artistName,
            lyrics,
            lyricTiming,
            clipStartSeconds: clipStart,
            durationSeconds: duration,
            showEndCard,
            endCardUrl: "",
            useArtworkColors: true,
            vibe,
            brand,
            beatGrid,
            showWatermark,
          },
    [
      isCanvas,
      audioUrl,
      artworkUrl,
      songTitle,
      artistName,
      lyrics,
      clipStart,
      duration,
      vibe,
      beatGrid,
      lyricTiming,
      brand,
      showWatermark,
      showEndCard,
    ]
  );

  // The Canvas loop needs no audio; every other format does.
  if (!audioUrl && !isCanvas) {
    return (
      <div className="flex aspect-[9/16] w-full max-w-[220px] items-center justify-center rounded-xl border border-borderline bg-surface text-xs text-muted">
        No preview
      </div>
    );
  }

  return (
    <div className={`w-full ${active === "wide" ? "max-w-[340px]" : "max-w-[220px]"}`}>
      <Player
        /* A key per format: the player holds internal state sized to the
           composition, and swapping the component and dimensions under it
           would leave that state stale. */
        key={active}
        component={isCanvas ? (CanvasLoop as never) : (SampleClip as never)}
        inputProps={inputProps as never}
        durationInFrames={
          isCanvas
            ? CANVAS_SECONDS * FPS
            : Math.max(
                1,
                Math.round((duration + (showEndCard ? END_CARD_SECONDS : 0)) * FPS)
              )
        }
        fps={FPS}
        compositionWidth={size.w}
        compositionHeight={size.h}
        style={{ width: "100%", borderRadius: 12, overflow: "hidden" }}
        controls
        doubleClickToFullscreen
        acknowledgeRemotionLicense
      />

      {formats.length > 1 ? (
        <div className="mt-1.5 flex flex-wrap gap-1">
          {formats.map((f) => (
            <button
              key={f}
              type="button"
              aria-pressed={f === active}
              onClick={() => setShown(f)}
              className={`rounded-full px-2 py-0.5 text-[10px] transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan ${
                f === active
                  ? "bg-cyan/20 text-foreground"
                  : "bg-surface-raised text-muted hover:text-foreground"
              }`}
            >
              {SIZES[f]?.label ?? f}
            </button>
          ))}
        </div>
      ) : null}

      <p className="mt-1 text-[11px] text-muted">
        {isCanvas
          ? "Live preview — 8s silent loop, built from your artwork and tempo."
          : "Live preview — the same template that renders your files."}
      </p>
    </div>
  );
}
