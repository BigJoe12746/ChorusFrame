import React from "react";
import { AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { BRAND_PALETTE, type Palette } from "./palette";
import { getVibe } from "./vibes";

/**
 * The Spotify Canvas loop: a silent 9:16 visual that plays behind a track,
 * 3–8 seconds, looping forever.
 *
 * Everything here is built to LOOP SEAMLESSLY: every animated value is a
 * periodic function of frame/durationInFrames, so the last frame hands off
 * to the first with no visible seam. That rule shapes two decisions:
 *
 *   - No audio reactivity. The song's waveform at 0:00 doesn't match 0:08,
 *     so audio-driven motion can never close the loop. Instead the pulse
 *     count per loop is derived from the song's detected BPM and rounded to
 *     a whole number of beats — the loop breathes at the track's tempo and
 *     still closes perfectly.
 *   - No end card, no watermark, no timeline. A Canvas is ambient artwork,
 *     not a clip.
 *
 * Vibe typography doesn't apply (there are no words); the vibe contributes
 * its palette, backdrop treatment, artwork mode and motion character.
 */
export type CanvasLoopProps = {
  artworkSrc: string | null;
  songTitle: string;
  vibe: string;
  brand?: {
    primary?: string | null;
    secondary?: string | null;
    font?: "sans" | "serif" | "mono" | null;
  } | null;
  beatGrid?: { bpm: number; offset: number } | null;
};

export const CANVAS_SECONDS = 8;

const resolveSrc = (src: string) => (src.startsWith("http") ? src : staticFile(src));

export const CanvasLoop: React.FC<CanvasLoopProps> = ({
  artworkSrc,
  songTitle,
  vibe,
  brand,
  beatGrid,
}) => {
  const frame = useCurrentFrame();
  const { durationInFrames, height } = useVideoConfig();
  const V = getVibe(vibe);
  const art = artworkSrc ? resolveSrc(artworkSrc) : null;

  // Fixed palette: artwork-colour extraction needs a browser image decode and
  // a delayed render, and the vibe's own colours already read as designed.
  // The brand kit still outranks them — a Canvas is exactly where an artist's
  // identity should hold.
  const palette: Palette = {
    primary: brand?.primary || (V.palette.mode === "fixed" ? V.palette.primary : BRAND_PALETTE.primary),
    secondary: brand?.secondary || (V.palette.mode === "fixed" ? V.palette.secondary : BRAND_PALETTE.secondary),
    fromArtwork: false,
  };

  // One full revolution over the loop — the seam-proof clock.
  const theta = (2 * Math.PI * frame) / durationInFrames;

  // Beats per loop, rounded to an integer so the pulse closes with the loop.
  // Half-time on fast tracks keeps the breathing calm rather than frantic.
  const bpm = beatGrid?.bpm ?? 0;
  const rawBeats = bpm > 0 ? (CANVAS_SECONDS * bpm) / 60 : 8;
  const beats = Math.max(4, Math.round(rawBeats > 20 ? rawBeats / 2 : rawBeats));
  // A kick, not a sine: sharpen the periodic wave so each pulse lands.
  const pulseWave = Math.pow(0.5 + 0.5 * Math.sin(theta * beats - Math.PI / 2), 3);
  const pulse = 1 + pulseWave * V.art.pulse * 0.8;

  // Slow periodic drift for the backdrop — a gentle figure-eight pan plus a
  // breath of zoom, all closing at theta = 2π.
  const panX = Math.sin(theta) * 22;
  const panY = Math.sin(2 * theta + Math.PI / 3) * 14;
  const breathe = 1 + 0.015 * Math.sin(theta + Math.PI / 2);
  const sway = V.art.sway * 0.6 * Math.sin(theta);

  const artMode = V.art.mode ?? "card";
  const artSize = 1080 * 0.62;

  return (
    <AbsoluteFill style={{ backgroundColor: V.background }}>
      {/* Backdrop: the artwork as atmosphere (or the vibe's gradient) */}
      <AbsoluteFill style={{ overflow: "hidden" }}>
        {art && artMode !== "none" ? (
          <Img
            src={art}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
              transform: `scale(${V.backdrop.scale * breathe}) translate(${panX}px, ${panY}px)`,
              filter: `blur(${V.backdrop.blur}px) saturate(${V.backdrop.saturate}) brightness(${V.backdrop.brightness})`,
            }}
          />
        ) : (
          <AbsoluteFill
            style={{
              background: `radial-gradient(circle at ${50 + 8 * Math.sin(theta)}% ${
                32 + 5 * Math.sin(2 * theta)
              }%, ${palette.secondary}44, ${V.background} 78%)`,
            }}
          />
        )}
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          background: `radial-gradient(ellipse at center, rgba(0,0,0,0) 45%, rgba(0,0,0,${V.vignette}) 100%)`,
        }}
      />

      {/* The artwork itself, breathing at the track's tempo */}
      {artMode === "card" ? (
        <div
          style={{
            position: "absolute",
            top: (1920 - artSize) / 2,
            left: (1080 - artSize) / 2,
            width: artSize,
            height: artSize,
            transform: `scale(${pulse}) rotate(${sway}deg)`,
            borderRadius: artSize * V.art.radiusScale,
            overflow: "hidden",
            border: V.art.ring ? `4px solid ${palette.primary}` : undefined,
            boxShadow: `0 60px 140px rgba(0,0,0,0.6), 0 0 ${
              (60 + pulseWave * 120) * V.art.glow
            }px ${palette.secondary}${pulseWave > 0.3 ? "77" : "44"}`,
          }}
        >
          {art ? (
            <Img src={art} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
          ) : (
            <div
              style={{
                width: "100%",
                height: "100%",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                background: `radial-gradient(circle at 30% 25%, ${palette.secondary}, ${V.background} 75%)`,
                fontFamily: 'Inter, "Liberation Sans", Arial, sans-serif',
                fontWeight: 800,
                fontSize: artSize * 0.5,
                color: "rgba(255,255,255,0.92)",
              }}
            >
              {(songTitle.trim()[0] || "♪").toUpperCase()}
            </div>
          )}
        </div>
      ) : null}

      {/* Ambient bars: periodic, beat-locked, deliberately abstract — they
          suggest music without pretending to read the waveform */}
      <div
        style={{
          position: "absolute",
          bottom: height * 0.09,
          left: 1080 * 0.14,
          width: 1080 * 0.72,
          height: height * 0.05,
          display: "flex",
          alignItems: "flex-end",
          justifyContent: "center",
          gap: 8,
          opacity: 0.55 * V.bars.opacity,
        }}
      >
        {Array.from({ length: 24 }, (_, i) => {
          const t = i / 23;
          // Each bar is its own periodic voice: integer multiples of theta
          // only, so every one of them closes with the loop.
          const level =
            0.25 +
            0.75 *
              Math.pow(
                0.5 +
                  0.5 *
                    Math.sin(theta * beats + i * 1.7) *
                    Math.sin(theta * 2 + i * 0.9),
                2
              );
          return (
            <div
              key={i}
              style={{
                width: 10,
                height: Math.max(6, level * height * 0.05),
                borderRadius: 5,
                background: t < 0.5 ? palette.primary : palette.secondary,
              }}
            />
          );
        })}
      </div>

      {/* Film grain, static — periodic by definition */}
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
    </AbsoluteFill>
  );
};
