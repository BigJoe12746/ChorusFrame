import React from "react";
import { Composition, staticFile } from "remotion";
import { getAudioDurationInSeconds } from "@remotion/media-utils";
import { SampleClip, FPS, END_CARD_SECONDS, type SampleClipProps } from "./SampleClip";

const defaultProps: SampleClipProps = {
  audioSrc: "demo/demo-song.wav",
  artworkSrc: "demo/demo-art.png",
  songTitle: "Midnight Run",
  artistName: "Demo Artist",
  lyrics:
    "City lights are calling out my name\nFoot down, midnight, chasing flame\nNever slowing down, never the same\nWe run, we run, we run",
  clipStartSeconds: 0,
  durationSeconds: 15,
  showEndCard: true,
};

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="SampleClip"
      component={SampleClip}
      width={1080}
      height={1920}
      fps={FPS}
      durationInFrames={Math.round((defaultProps.durationSeconds + END_CARD_SECONDS) * FPS)}
      defaultProps={defaultProps}
      calculateMetadata={async ({ props }) => {
        // Validate the clip window against the real song length so an overrun
        // fails the render loudly instead of producing silent, flatlined video.
        const src = props.audioSrc.startsWith("http")
          ? props.audioSrc
          : staticFile(props.audioSrc);
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
      }}
    />
  );
};
