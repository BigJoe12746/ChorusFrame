"use client";

import { Player } from "@remotion/player";
import { useMemo } from "react";
import { SampleClip, FPS, END_CARD_SECONDS } from "@/remotion/SampleClip";

/**
 * Live preview of the clip, in the browser.
 *
 * This mounts the SAME component the worker renders — not a mock-up — so
 * "the preview matches the export" is true by construction rather than by
 * effort. Changing the vibe, the hook or the clip length re-renders it
 * immediately, which is what stops the render queue from being the feedback
 * loop.
 */
export default function ClipPreview({
  audioUrl,
  artworkUrl,
  songTitle,
  artistName,
  lyrics,
  clipStart,
  duration,
  vibe,
}: {
  audioUrl: string | null;
  artworkUrl: string | null;
  songTitle: string;
  artistName: string;
  lyrics: string;
  clipStart: number;
  duration: number;
  vibe: string;
}) {
  const inputProps = useMemo(
    () => ({
      audioSrc: audioUrl ?? "",
      artworkSrc: artworkUrl,
      songTitle,
      artistName,
      lyrics,
      // Left empty on purpose: with no timing supplied the composition spreads
      // the lines across the clip, which is exactly what a render does today
      // while no transcription key is configured.
      lyricTiming: [],
      clipStartSeconds: clipStart,
      durationSeconds: duration,
      showEndCard: true,
      endCardUrl: "",
      useArtworkColors: true,
      vibe,
    }),
    [audioUrl, artworkUrl, songTitle, artistName, lyrics, clipStart, duration, vibe]
  );

  if (!audioUrl) {
    return (
      <div className="flex aspect-[9/16] w-full max-w-[220px] items-center justify-center rounded-xl border border-borderline bg-surface text-xs text-muted">
        No preview
      </div>
    );
  }

  return (
    <div className="w-full max-w-[220px]">
      <Player
        component={SampleClip}
        inputProps={inputProps}
        durationInFrames={Math.max(1, Math.round((duration + END_CARD_SECONDS) * FPS))}
        fps={FPS}
        compositionWidth={1080}
        compositionHeight={1920}
        style={{ width: "100%", borderRadius: 12, overflow: "hidden" }}
        controls
        doubleClickToFullscreen
        acknowledgeRemotionLicense
      />
      <p className="mt-1 text-[11px] text-muted">
        Live preview — the same template that renders your files.
      </p>
    </div>
  );
}
