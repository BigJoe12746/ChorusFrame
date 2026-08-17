import React, { useEffect, useRef, useState } from "react";
import {
  AbsoluteFill,
  Audio,
  Img,
  continueRender,
  delayRender,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { useAudioData, visualizeAudio } from "@remotion/media-utils";
import { getLayout } from "./layout";
import { BRAND_PALETTE, extractPalette, type Palette } from "./palette";
import { DEFAULT_VIBE, getVibe } from "./vibes";

export type SampleClipProps = {
  audioSrc: string;
  artworkSrc: string | null;
  songTitle: string;
  artistName: string;
  /** Raw lyrics; lines separated by newlines. Empty string = no lyrics shown. */
  lyrics: string;
  /**
   * Timed lines, in seconds from the start of THIS clip. When present they
   * drive the lyric display; when empty the lines are spread across the clip.
   */
  lyricTiming: { text: string; start: number; end: number }[];
  /** Where in the song the clip window begins, in seconds. */
  clipStartSeconds: number;
  /** Musical length of the clip (excluding the end card), in seconds. */
  durationSeconds: number;
  showEndCard: boolean;
  /** Shown under the end-card wordmark. Empty until a domain is live. */
  endCardUrl: string;
  /** Theme accents from the cover art instead of brand colors. */
  useArtworkColors: boolean;
  /** Visual direction — see remotion/vibes.ts. */
  vibe: string;
};

export const FPS = 30;
export const END_CARD_SECONDS = 2.6;

const NAVY = "#080b16";
const FONT = 'Inter, "Segoe UI", system-ui, -apple-system, sans-serif';

const resolveSrc = (src: string) => (src.startsWith("http") ? src : staticFile(src));

/**
 * Reads accent colors out of the cover art. Holds the render until the image
 * has been sampled, then falls back to brand colors if anything goes wrong
 * (missing artwork, cross-origin block, greyscale cover).
 */
function useArtworkPalette(src: string | null, enabled: boolean): Palette {
  const [palette, setPalette] = useState<Palette>(BRAND_PALETTE);
  const [handle] = useState(() => delayRender("Reading artwork colors"));
  const settled = useRef(false);

  useEffect(() => {
    const finish = (next?: Palette | null) => {
      if (settled.current) return;
      settled.current = true;
      if (next) setPalette(next);
      continueRender(handle);
    };

    if (!src || !enabled) {
      finish();
      return;
    }
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => finish(extractPalette(img));
    img.onerror = () => finish();
    img.src = src;
    return () => finish();
  }, [src, enabled, handle]);

  return palette;
}

function LogoMark({ size, id, accent }: { size: number; id: string; accent: string }) {
  return (
    <svg width={size} height={(size * 48) / 64} viewBox="0 0 64 48" fill="none">
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={accent} />
          <stop offset="100%" stopColor="#2b8cff" />
        </linearGradient>
      </defs>
      <rect x="3.5" y="3.5" width="57" height="41" rx="12" stroke={`url(#${id})`} strokeWidth="6" />
      <path
        d="M13 24h4.5l3-9.5 4 18.5 3.5-13 2.5 8 3-4H51"
        stroke={`url(#${id})`}
        strokeWidth="3"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M29.5 17L43 24l-13.5 7V17Z" fill="#7c3aed" />
    </svg>
  );
}

/** Fallback art when no artwork was uploaded: gradient monogram card. */
function MonogramArt({
  title,
  palette,
  size,
}: {
  title: string;
  palette: Palette;
  size: number;
}) {
  const letter = (title.trim()[0] || "♪").toUpperCase();
  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: `radial-gradient(circle at 30% 25%, ${palette.secondary}, ${NAVY} 75%)`,
      }}
    >
      <span
        style={{
          fontFamily: FONT,
          fontWeight: 800,
          fontSize: size * 0.52,
          lineHeight: 1,
          color: "rgba(255,255,255,0.92)",
        }}
      >
        {letter}
      </span>
    </div>
  );
}

function EndCard({
  startFrame,
  unit,
  palette,
  url,
}: {
  startFrame: number;
  unit: number;
  palette: Palette;
  url: string;
}) {
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
        gap: unit * 0.033,
      }}
    >
      <div style={{ transform: `scale(${0.8 + 0.2 * pop})` }}>
        <LogoMark size={unit * 0.19} id="endcard-mark" accent={palette.primary} />
      </div>
      <div style={{ fontFamily: FONT, textAlign: "center" }}>
        <div style={{ color: "#eef0f8", fontSize: unit * 0.05, fontWeight: 700 }}>
          Made with ChorusFrame
        </div>
        {url ? (
          <div
            style={{
              color: palette.primary,
              fontSize: unit * 0.031,
              marginTop: unit * 0.013,
              fontWeight: 500,
            }}
          >
            {url}
          </div>
        ) : null}
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
  lyricTiming,
  clipStartSeconds,
  durationSeconds,
  showEndCard,
  endCardUrl,
  useArtworkColors,
  vibe,
}) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();
  const src = resolveSrc(audioSrc);
  const audioData = useAudioData(src);
  const V = getVibe(vibe);
  const art = artworkSrc ? resolveSrc(artworkSrc) : null;
  // A vibe with a fixed palette keeps its own colours whatever the cover looks
  // like — that identity is the point of choosing it.
  const artPalette = useArtworkPalette(art, useArtworkColors && V.palette.mode === "artwork");
  const palette: Palette =
    V.palette.mode === "fixed" || !artPalette.fromArtwork
      ? { primary: V.palette.primary, secondary: V.palette.secondary, fromArtwork: false }
      : artPalette;
  const L = getLayout(width, height);

  const musicFrames = Math.round(durationSeconds * fps);
  const totalFrames = musicFrames + (showEndCard ? Math.round(END_CARD_SECONDS * fps) : 0);

  if (!audioData) {
    return null; // useAudioData delays the render until the audio is decoded
  }

  // Clamp to the last real audio frame so an overrun can never flatline the visuals
  const maxMediaFrame = Math.max(0, Math.floor(audioData.durationInSeconds * fps) - 1);
  const mediaFrame = Math.min(frame + Math.round(clipStartSeconds * fps), maxMediaFrame);

  // Frequency data drives everything: bass → artwork pulse, mid → bars
  const freq = visualizeAudio({ audioData, frame: mediaFrame, fps, numberOfSamples: 64 });
  const bass = (freq[0] + freq[1] + freq[2] + freq[3] + freq[4]) / 5;
  const pulse = 1 + Math.min(bass * 1.4, 1) * V.art.pulse;

  // Intro entrance — a vibe can make it snap or drift
  const intro = spring({
    frame,
    fps,
    config: { damping: 200 },
    durationInFrames: Math.round(24 * V.motion),
  });
  const headerShift = interpolate(intro, [0, 1], [-L.unit * 0.056, 0]);

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

  // Timed lines win when we have them: each line appears when it is actually
  // sung. Without timing, fall back to spreading the lines across the clip.
  const timed: { text: string; startF: number; endF: number }[] = lyricTiming?.length
    ? lyricTiming
        .flatMap((l) => {
          const parts = wrapLine(l.text);
          const span = (l.end - l.start) / Math.max(1, parts.length);
          return parts.map((text, i) => ({
            text,
            startF: (l.start + span * i) * fps,
            endF: (l.start + span * (i + 1)) * fps,
          }));
        })
        // calculateMetadata shortens durationSeconds when the clip window runs
        // past the end of the song, so timings built for the requested length
        // can point beyond the music. Drop what falls outside and clamp the
        // line that straddles the boundary rather than truncating the tail.
        .filter((l) => l.startF < musicFrames)
        .map((l) => ({ ...l, endF: Math.min(l.endF, musicFrames) }))
        .filter((l) => l.endF > l.startF)
    : (() => {
        const lines = lyrics
          .split(/\r?\n/)
          .map((l) => l.trim())
          .filter(Boolean)
          .flatMap(wrapLine)
          .slice(0, maxLines);
        const startF = 1.0 * fps;
        const endF = musicFrames - 0.8 * fps;
        const per = lines.length ? (endF - startF) / lines.length : 0;
        return lines.map((text, i) => ({
          text,
          startF: startF + per * i,
          endF: startF + per * (i + 1),
        }));
      })();

  const active = timed.find((l) => frame >= l.startF && frame < l.endF) ?? null;
  const lineFrame = active ? frame - active.startF : 0;
  const lineSpan = active ? active.endF - active.startF : 0;
  // Entrance and exit have to be sized together, or a short line spends its
  // whole life ramping in while already fading out and never reads clearly.
  const settleFrames = Math.min(16, Math.max(4, lineSpan * 0.4));
  const lineIn = spring({
    frame: lineFrame,
    fps,
    config: { damping: 16, mass: 0.6 },
    durationInFrames: Math.round(settleFrames),
  });
  const fadeFrames = Math.min(8, Math.max(2, lineSpan * 0.25));
  const lineOut =
    lineSpan > 0
      ? interpolate(
          lineFrame,
          // Never begin fading before the entrance has landed
          [Math.max(settleFrames, lineSpan - fadeFrames), lineSpan],
          [1, 0],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
        )
      : 1;

  const bars = freq.slice(2, 2 + L.bars.count);
  const barWidth = L.bars.width / bars.length;

  const progress = Math.min(frame / musicFrames, 1);
  // Fade the song out at the END of the musical window, not the end card —
  // a "15s sample" should expose exactly 15s of the track.
  const fadeOut = interpolate(frame, [musicFrames - fps, musicFrames], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  // Short ramp-in when slicing mid-song, so the cut doesn't click
  const fadeIn =
    clipStartSeconds > 0 ? interpolate(frame, [0, 12], [0, 1], { extrapolateRight: "clamp" }) : 1;

  const artMode = V.art.mode ?? "card";
  // Centred lyrics belong to templates where the words are the main event
  // (full-bleed cover, or no cover at all) rather than a caption under a card.
  const lyricTop =
    V.lyricPlacement === "center" ? Math.round(height * 0.42) : L.lyric.top;

  const artSway = Math.sin(frame / 55) * V.art.sway;
  const bgDrift = frame * 0.12;

  // Letterbox eats the bottom of the frame, so the whole lower cluster
  // (waveform + watermark) moves up together rather than one piece sliding
  // into the other.
  const letterboxHeight = height * 0.055;
  const bottomLift = V.letterbox ? letterboxHeight : 0;

  return (
    <AbsoluteFill style={{ backgroundColor: V.background, fontFamily: V.fonts.title }}>
      <Audio
        src={src}
        startFrom={Math.round(clipStartSeconds * fps)}
        endAt={Math.round(clipStartSeconds * fps) + musicFrames}
        volume={() => fadeIn * fadeOut}
      />

      {/* Artwork backdrop. For "full" templates this is the picture itself —
          barely blurred, near full brightness — rather than a wash behind a
          card. "none" skips it so type carries the clip. */}
      <AbsoluteFill style={{ overflow: "hidden" }}>
        {art && artMode !== "none" ? (
          <Img
            src={art}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              transform: `scale(${V.backdrop.scale}) rotate(${bgDrift * 0.05}deg) translateY(${
                Math.sin(frame / 90) * 14
              }px)`,
              filter: `blur(${V.backdrop.blur}px) saturate(${V.backdrop.saturate}) brightness(${V.backdrop.brightness})`,
            }}
          />
        ) : (
          <AbsoluteFill
            style={{
              background: `radial-gradient(circle at 50% 30%, ${palette.secondary}33, ${V.background} 80%)`,
            }}
          />
        )}
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          background: `radial-gradient(ellipse at center, rgba(0,0,0,0) 45%, rgba(0,0,0,${V.vignette}) 100%)`,
        }}
      />

      {/* Progress bar — sits below the letterbox bar rather than under it */}
      <div
        style={{
          position: "absolute",
          top: bottomLift,
          left: 0,
          height: L.progressHeight,
          width: `${progress * 100}%`,
          background: `linear-gradient(90deg, ${palette.secondary}, ${palette.primary})`,
        }}
      />

      {/* Header: artist + title */}
      <div
        style={{
          position: "absolute",
          top: L.header.top,
          left: L.header.left,
          width: L.header.width,
          textAlign: L.header.align,
          transform: `translateY(${headerShift}px)`,
          opacity: intro,
        }}
      >
        {artistName ? (
          <div
            style={{
              color: palette.primary,
              fontSize: L.header.artistSize,
              fontWeight: V.artistLabel.weight,
              letterSpacing: V.artistLabel.letterSpacing,
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
            fontSize:
              songTitle.length > 40
                ? L.header.titleSize * 0.61
                : songTitle.length > 22
                  ? L.header.titleSize * 0.78
                  : L.header.titleSize,
            fontWeight: V.title.weight,
            fontStyle: V.title.italic ? "italic" : "normal",
            letterSpacing: V.title.letterSpacing,
            textTransform: V.title.transform,
            marginTop: L.unit * 0.017,
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

      {/* Artwork card, pulsing with the bass.
          "full" templates let the backdrop be the picture and "none" templates
          drop it entirely, so the card only belongs to the framed look. */}
      {artMode === "card" ? (
      <div
        style={{
          position: "absolute",
          top: L.art.top,
          left: L.art.left,
          width: L.art.size,
          height: L.art.size,
          transform: `scale(${(0.82 + 0.18 * intro) * pulse}) rotate(${artSway}deg)`,
          borderRadius: L.art.size * V.art.radiusScale,
          overflow: "hidden",
          border: V.art.ring ? `${Math.max(2, L.unit * 0.004)}px solid ${palette.primary}` : undefined,
          boxShadow: `0 ${L.unit * 0.055}px ${L.unit * 0.13}px rgba(0,0,0,0.6), 0 0 ${
            (L.unit * 0.055 + bass * L.unit * 0.15) * V.art.glow
          }px ${palette.secondary}${bass > 0.3 ? "88" : "44"}`,
        }}
      >
        {art ? (
          <Img src={art} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        ) : (
          <MonogramArt title={songTitle} palette={palette} size={L.art.size} />
        )}
      </div>
      ) : null}

      {/* Active lyric line */}
      {active ? (
        <div
          style={{
            position: "absolute",
            top: lyricTop,
            left: L.lyric.left,
            width: L.lyric.width,
            textAlign: L.lyric.align,
            opacity: Math.min(lineIn, lineOut),
            transform: `translateY(${(1 - lineIn) * L.unit * 0.043}px)`,
            maxHeight: L.lyric.maxHeight,
            overflow: "hidden",
          }}
        >
          <span
            style={{
              color: "#ffffff",
              fontFamily: V.fonts.lyric,
              fontSize:
                (active.text.length > 54 ? L.lyric.size * 0.79 : L.lyric.size) *
                V.lyric.sizeScale,
              fontWeight: V.lyric.weight,
              fontStyle: V.lyric.italic ? "italic" : "normal",
              letterSpacing: V.lyric.letterSpacing,
              textTransform: V.lyric.transform,
              lineHeight: 1.25,
              textShadow: V.lyric.shadow,
            }}
          >
            {active.text}
          </span>
        </div>
      ) : null}

      {/* Audio visualizer — its shape is part of the vibe, not just its colour */}
      {V.bars.style !== "none" ? (
        <div
          style={{
            position: "absolute",
            top: L.bars.top - bottomLift,
            left: L.bars.left,
            width: L.bars.width,
            height: L.bars.height,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            opacity: V.bars.opacity,
          }}
        >
          {bars.map((v, i) => {
            const level = Math.min(1, Math.pow(v * 4.5, 0.75));
            const t = i / Math.max(1, bars.length - 1);
            const color = t < 0.5 ? palette.primary : palette.secondary;
            const w = barWidth * V.bars.thickness;

            if (V.bars.style === "dots") {
              // Circles that swell with the level and drift off the centre line
              const d = w * (0.5 + level * 0.9);
              return (
                <div
                  key={i}
                  style={{
                    width: w,
                    height: L.bars.height,
                    marginRight: barWidth - w,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    transform: `translateY(${-level * L.bars.height * 0.22}px)`,
                  }}
                >
                  <div style={{ width: d, height: d, borderRadius: "50%", background: color }} />
                </div>
              );
            }

            if (V.bars.style === "line") {
              // A thin symmetric trace — reads as an instrument readout
              const h = Math.max(2, level * L.bars.height * 0.82);
              return (
                <div
                  key={i}
                  style={{
                    width: w,
                    marginRight: barWidth - w,
                    height: h,
                    background: color,
                    borderRadius: 0,
                  }}
                />
              );
            }

            // "bars" — chunky columns anchored to the baseline
            const h = L.bars.height * 0.06 + level * L.bars.height * 0.86;
            return (
              <div
                key={i}
                style={{
                  width: w,
                  marginRight: barWidth - w,
                  height: h,
                  borderRadius: w * V.bars.radiusScale,
                  background: `linear-gradient(180deg, ${color}, ${palette.secondary})`,
                }}
              />
            );
          })}
        </div>
      ) : null}

      {/* Watermark — lifted clear of the letterbox bar when there is one */}
      <div
        style={{
          position: "absolute",
          top: L.watermark.top - bottomLift,
          left: L.watermark.left,
          width: L.watermark.width,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: L.unit * 0.013,
          opacity: 0.75,
        }}
      >
        <LogoMark size={L.unit * 0.05} id="watermark-mark" accent={palette.primary} />
        <span style={{ color: "#8b93b5", fontSize: L.watermark.size, fontWeight: 600 }}>
          ChorusFrame
        </span>
      </div>

      {/* Film grain — a static tile, so it costs nothing per frame */}
      {V.grain > 0 ? (
        <AbsoluteFill
          style={{
            opacity: V.grain,
            pointerEvents: "none",
            backgroundImage:
              "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='140' height='140'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='3'/></filter><rect width='140' height='140' filter='url(%23n)' opacity='0.55'/></svg>\")",
            backgroundRepeat: "repeat",
            mixBlendMode: "overlay",
          }}
        />
      ) : null}

      {/* Letterbox bars, drawn last so nothing sits on top of them */}
      {V.letterbox ? (
        <>
          <div
            style={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              height: letterboxHeight,
              background: "#000",
            }}
          />
          <div
            style={{
              position: "absolute",
              bottom: 0,
              left: 0,
              width: "100%",
              height: letterboxHeight,
              background: "#000",
            }}
          />
        </>
      ) : null}

      {showEndCard && frame >= musicFrames ? (
        <EndCard startFrame={musicFrames} unit={L.unit} palette={palette} url={endCardUrl} />
      ) : null}
    </AbsoluteFill>
  );
};
