import React from "react";
import { Composition, staticFile } from "remotion";
import { getAudioDurationInSeconds } from "@remotion/media-utils";
import { SampleClip, FPS, END_CARD_SECONDS, type SampleClipProps } from "./SampleClip";
import { CanvasLoop, CANVAS_SECONDS } from "./CanvasLoop";
import { DEFAULT_VIBE } from "./vibes";

const defaultProps: SampleClipProps = {
  audioSrc: "demo/demo-song.wav",
  artworkSrc: "demo/demo-art.png",
  songTitle: "Midnight Run",
  artistName: "Demo Artist",
  lyrics:
    "City lights are calling out my name\nFoot down, midnight, chasing flame\nNever slowing down, never the same\nWe run, we run, we run",
  lyricTiming: [],
  brand: null,
  beatGrid: null,
  clipStartSeconds: 0,
  durationSeconds: 15,
  showEndCard: true,
  endCardUrl: "",
  useArtworkColors: true,
  vibe: DEFAULT_VIBE,
};

/**
 * Validate the clip window against the real song length so an overrun fails the
 * render loudly instead of producing silent, flatlined video.
 */
const calculateMetadata = async ({ props }: { props: SampleClipProps }) => {
  const src = props.audioSrc.startsWith("http") ? props.audioSrc : staticFile(props.audioSrc);
  const audioDur = await getAudioDurationInSeconds(src);
  if (props.clipStartSeconds >= audioDur - 5) {
    throw new Error(
      `Clip start ${props.clipStartSeconds}s is beyond the ${audioDur.toFixed(1)}s song (need at least 5s of music after it)`
    );
  }
  const music = Math.min(props.durationSeconds, audioDur - props.clipStartSeconds);
  return {
    props: { ...props, durationSeconds: music },
    durationInFrames: Math.round(
      (music + (props.showEndCard ? END_CARD_SECONDS : 0)) * FPS
    ),
  };
};

/** Every export format comes from this one composition. */
export const FORMATS = [
  { id: "SampleClip", width: 1080, height: 1920, label: "vertical 9:16" },
  { id: "SampleClipSquare", width: 1080, height: 1080, label: "square 1:1" },
  { id: "SampleClipWide", width: 1920, height: 1080, label: "wide 16:9" },
] as const;

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* The Spotify Canvas loop: fixed length, no audio, seam-free by
          construction — reads the same props file as the clip formats. */}
      <Composition
        id="CanvasLoop"
        component={CanvasLoop}
        width={1080}
        height={1920}
        fps={FPS}
        durationInFrames={CANVAS_SECONDS * FPS}
        defaultProps={{
          artworkSrc: defaultProps.artworkSrc,
          songTitle: defaultProps.songTitle,
          vibe: defaultProps.vibe,
          brand: null,
          beatGrid: null,
        }}
      />
      {FORMATS.map((f) => (
        <Composition
          key={f.id}
          id={f.id}
          component={SampleClip}
          width={f.width}
          height={f.height}
          fps={FPS}
          durationInFrames={Math.round(
            (defaultProps.durationSeconds + END_CARD_SECONDS) * FPS
          )}
          defaultProps={defaultProps}
          calculateMetadata={calculateMetadata}
        />
      ))}
    </>
  );
};
