import React from "react";
import {
  AbsoluteFill,
  Audio,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { useAudioData, visualizeAudio } from "@remotion/media-utils";

export type SampleClipProps = {
  audioSrc: string;
  artworkSrc: string | null;
  songTitle: string;
  artistName: string;
  /** Raw lyrics; lines separated by newlines. Empty string = no lyrics shown. */
  lyrics: string;
  /** Where in the song the clip window begins, in seconds. */
  clipStartSeconds: number;
  /** Musical length of the clip (excluding the end card), in seconds. */
  durationSeconds: number;
  showEndCard: boolean;
};

export const FPS = 30;
export const END_CARD_SECONDS = 2.6;

const NAVY = "#080b16";
const VIOLET = "#8b5cf6";
const VIOLET_STRONG = "#7c3aed";
const CORAL = "#ff6b5e";
const FONT = 'Inter, "Segoe UI", system-ui, -apple-system, sans-serif';

const resolveSrc = (src: string) =>
  src.startsWith("http") ? src : staticFile(src);

function Logo({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 26 26" fill="none">
      <rect x="1.5" y="1.5" width="23" height="23" rx="5" stroke={VIOLET} strokeWidth="2" />
      <path d="M10 8.5L17.5 13L10 17.5V8.5Z" fill={CORAL} />
      <path d="M5 13c1.2-2.2 2.2 2.2 3.4 0" stroke={VIOLET} strokeWidth="1.4" strokeLinecap="round" fill="none" />
    </svg>
  );
}

/** Fallback art when no artwork was uploaded: gradient monogram card. */
function MonogramArt({ title }: { title: string }) {
  const letter = (title.trim()[0] || "♪").toUpperCase();
  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: `radial-gradient(circle at 30% 25%, ${VIOLET_STRONG}, ${NAVY} 75%)`,
      }}
    >
      <span style={{ fontFamily: FONT, fontWeight: 800, fontSize: 380, color: "rgba(255,255,255,0.92)" }}>
        {letter}
      </span>
    </div>
  );
}

function EndCard({ startFrame }: { startFrame: number }) {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const local = frame - startFrame;
  const opacity = interpolate(local, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const pop = spring({ frame: local, fps, config: { damping: 200 } });
  return (
    <AbsoluteFill
      style={{
        backgroundColor: NAVY,
        opacity,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flexDirection: "column",
        gap: 36,
      }}
    >
      <div style={{ transform: `scale(${0.8 + 0.2 * pop})` }}>
        <Logo size={140} />
      </div>
      <div style={{ fontFamily: FONT, textAlign: "center" }}>
        <div style={{ color: "#eef0f8", fontSize: 54, fontWeight: 700 }}>
          Made with VerseFrame
        </div>
        <div style={{ color: CORAL, fontSize: 34, marginTop: 14, fontWeight: 500 }}>
          verseframe.vercel.app
        </div>
      </div>
    </AbsoluteFill>
  );
}

export const SampleClip: React.FC<SampleClipProps> = ({
  audioSrc,
  artworkSrc,
  songTitle,
  artistName,
  lyrics,
  clipStartSeconds,
  durationSeconds,
  showEndCard,
}) => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();
  const src = resolveSrc(audioSrc);
  const audioData = useAudioData(src);

  const musicFrames = Math.round(durationSeconds * fps);
  const totalFrames = musicFrames + (showEndCard ? Math.round(END_CARD_SECONDS * fps) : 0);

  if (!audioData) {
    return null; // useAudioData delays the render until the audio is decoded
  }

  // Clamp to the last real audio frame so an overrun can never flatline the visuals
  const maxMediaFrame = Math.max(0, Math.floor(audioData.durationInSeconds * fps) - 1);
  const mediaFrame = Math.min(frame + Math.round(clipStartSeconds * fps), maxMediaFrame);

  // Frequency data drives everything: bass → artwork pulse, full range → bars
  const freq = visualizeAudio({ audioData, frame: mediaFrame, fps, numberOfSamples: 64 });
  const bass = (freq[0] + freq[1] + freq[2] + freq[3] + freq[4]) / 5;
  const pulse = 1 + Math.min(bass * 1.4, 1) * 0.05;

  // Intro entrance
  const intro = spring({ frame, fps, config: { damping: 200 }, durationInFrames: 24 });
  const headerY = interpolate(intro, [0, 1], [-60, 0]);

  // Lyrics: re-break long source lines on word boundaries (paragraph-pasted
  // lyrics arrive as one giant "line"), then distribute across the music window.
  // Line cap scales with clip length so each line has time to spring in + fade.
  const wrapLine = (l: string) => {
    const out: string[] = [];
    let cur = "";
    for (const w of l.split(/\s+/)) {
      const next = cur ? `${cur} ${w}` : w;
      if (next.length > 90) {
        if (cur) out.push(cur);
        cur = w;
      } else cur = next;
    }
    if (cur) out.push(cur);
    return out;
  };
  const maxLines = Math.min(10, Math.max(1, Math.floor((musicFrames - 54) / 26)));
  const lines = lyrics
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean)
    .flatMap(wrapLine)
    .slice(0, maxLines);
  const lyricsStart = 1.0 * fps;
  const lyricsEnd = musicFrames - 0.8 * fps;
  const perLine = lines.length > 0 ? (lyricsEnd - lyricsStart) / lines.length : 0;
  const rawIndex = perLine > 0 ? Math.floor((frame - lyricsStart) / perLine) : -1;
  const lineIndex = frame >= lyricsStart && frame < lyricsEnd ? Math.min(Math.max(rawIndex, 0), lines.length - 1) : -1;
  const lineFrame = lineIndex >= 0 ? frame - (lyricsStart + lineIndex * perLine) : 0;
  const lineIn = spring({ frame: lineFrame, fps, config: { damping: 16, mass: 0.6 } });
  const lineOut = perLine > 0 ? interpolate(lineFrame, [perLine - 8, perLine], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) : 1;

  // Waveform: 32 bars from the low/mid spectrum, where the music actually lives
  const bars = freq.slice(2, 34);
  const barWidth = Math.floor((width - 240) / bars.length);

  const progress = Math.min(frame / musicFrames, 1);
  // Fade the song out at the END of the musical window, not the end card —
  // a "15s sample" should expose exactly 15s of the track.
  const fadeOut = interpolate(frame, [musicFrames - fps, musicFrames], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  // Short ramp-in when slicing mid-song, so the cut doesn't click
  const fadeIn =
    clipStartSeconds > 0
      ? interpolate(frame, [0, 12], [0, 1], { extrapolateRight: "clamp" })
      : 1;

  const artSway = Math.sin(frame / 55) * 1.1;
  const bgDrift = frame * 0.12;

  return (
    <AbsoluteFill style={{ backgroundColor: NAVY, fontFamily: FONT }}>
      <Audio
        src={src}
        startFrom={Math.round(clipStartSeconds * fps)}
        endAt={Math.round(clipStartSeconds * fps) + musicFrames}
        volume={() => fadeIn * fadeOut}
      />

      {/* Blurred artwork backdrop */}
      <AbsoluteFill style={{ overflow: "hidden" }}>
        {artworkSrc ? (
          <Img
            src={resolveSrc(artworkSrc)}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              transform: `scale(2.3) rotate(${bgDrift * 0.05}deg) translateY(${Math.sin(frame / 90) * 14}px)`,
              filter: "blur(70px) saturate(1.35) brightness(0.5)",
            }}
          />
        ) : (
          <AbsoluteFill
            style={{ background: `radial-gradient(circle at 50% 30%, #1c1440, ${NAVY} 80%)` }}
          />
        )}
      </AbsoluteFill>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at center, rgba(8,11,22,0) 45%, rgba(8,11,22,0.75) 100%)" }} />

      {/* Progress bar */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          height: 8,
          width: `${progress * 100}%`,
          background: `linear-gradient(90deg, ${VIOLET_STRONG}, ${CORAL})`,
        }}
      />

      {/* Header: artist + title */}
      <div
        style={{
          position: "absolute",
          top: 150,
          width: "100%",
          textAlign: "center",
          transform: `translateY(${headerY}px)`,
          opacity: intro,
          padding: "0 90px",
        }}
      >
        {artistName ? (
          <div
            style={{
              color: CORAL,
              fontSize: 34,
              fontWeight: 600,
              letterSpacing: "0.28em",
              textTransform: "uppercase",
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {artistName}
          </div>
        ) : null}
        <div
          style={{
            color: "#eef0f8",
            fontSize: songTitle.length > 40 ? 44 : songTitle.length > 22 ? 56 : 72,
            fontWeight: 800,
            marginTop: 18,
            lineHeight: 1.1,
            display: "-webkit-box",
            WebkitLineClamp: 2,
            WebkitBoxOrient: "vertical",
            overflow: "hidden",
          }}
        >
          {songTitle}
        </div>
      </div>

      {/* Artwork card, pulsing with the bass */}
      <div
        style={{
          position: "absolute",
          top: 480,
          left: "50%",
          width: 720,
          height: 720,
          transform: `translateX(-50%) scale(${(0.82 + 0.18 * intro) * pulse}) rotate(${artSway}deg)`,
          borderRadius: 36,
          overflow: "hidden",
          boxShadow: `0 60px 140px rgba(0,0,0,0.6), 0 0 ${60 + bass * 160}px rgba(139,92,246,${0.25 + Math.min(bass, 0.5) * 0.5})`,
        }}
      >
        {artworkSrc ? (
          <Img src={resolveSrc(artworkSrc)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        ) : (
          <MonogramArt title={songTitle} />
        )}
      </div>

      {/* Active lyric line */}
      {lineIndex >= 0 ? (
        <div
          style={{
            position: "absolute",
            top: 1310,
            width: "100%",
            padding: "0 110px",
            textAlign: "center",
            opacity: Math.min(lineIn, lineOut),
            transform: `translateY(${(1 - lineIn) * 46}px)`,
            maxHeight: 210,
            overflow: "hidden",
          }}
        >
          <span
            style={{
              color: "#ffffff",
              fontSize: lines[lineIndex].length > 54 ? 44 : 56,
              fontWeight: 700,
              lineHeight: 1.25,
              textShadow: "0 4px 30px rgba(0,0,0,0.65)",
            }}
          >
            {lines[lineIndex]}
          </span>
        </div>
      ) : null}

      {/* Waveform bars */}
      <div
        style={{
          position: "absolute",
          bottom: 190,
          left: 120,
          right: 120,
          height: 200,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 6,
        }}
      >
        {bars.map((v, i) => {
          const t = i / (bars.length - 1);
          // tilt compensates the natural high-frequency falloff of music spectra
          const h = 12 + Math.min(1, Math.pow(v * 4.5 * (0.8 + t * 2.2), 0.75)) * 172;
          return (
            <div
              key={i}
              style={{
                width: barWidth - 6,
                height: h,
                borderRadius: 6,
                background: `linear-gradient(180deg, ${t < 0.5 ? VIOLET : CORAL}, ${VIOLET_STRONG})`,
                opacity: 0.9,
              }}
            />
          );
        })}
      </div>

      {/* Watermark */}
      <div
        style={{
          position: "absolute",
          bottom: 90,
          width: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 14,
          opacity: 0.75,
        }}
      >
        <Logo size={40} />
        <span style={{ color: "#8b93b5", fontSize: 28, fontWeight: 500 }}>VerseFrame</span>
      </div>

      {showEndCard && frame >= musicFrames ? <EndCard startFrame={musicFrames} /> : null}
    </AbsoluteFill>
  );
};
