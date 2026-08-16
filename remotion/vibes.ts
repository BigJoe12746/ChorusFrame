// Visual directions.
//
// A vibe is not a colour swap. Each one changes typography, motion, the shape
// of the waveform, how the artwork is treated, and how lyrics are set — so a
// reggae track and a dark-anime track read as different pieces of design
// rather than the same template tinted differently.
//
// Font stacks stay on families that exist both on a dev machine and in the
// worker image (fonts-liberation), so a vibe never silently falls back to the
// same sans on the render host.

const SANS = 'Inter, "Segoe UI", "Liberation Sans", Arial, system-ui, sans-serif';
const SERIF = 'Georgia, "Liberation Serif", "Times New Roman", serif';
const MONO = '"Liberation Mono", "Courier New", ui-monospace, monospace';

export type BarStyle = "bars" | "dots" | "line" | "none";

export type Vibe = {
  id: string;
  label: string;
  /** Shown in the picker so an artist can choose without rendering first. */
  blurb: string;
  fonts: { title: string; lyric: string };
  title: {
    weight: number;
    transform: "none" | "uppercase";
    letterSpacing: string;
    italic?: boolean;
  };
  artistLabel: { letterSpacing: string; weight: number };
  lyric: {
    weight: number;
    transform: "none" | "uppercase" | "lowercase";
    letterSpacing: string;
    italic?: boolean;
    shadow: string;
    sizeScale: number;
  };
  /** "artwork" themes from the cover; "fixed" always uses the vibe's own colours. */
  palette: { mode: "artwork" | "fixed"; primary: string; secondary: string };
  background: string;
  backdrop: { blur: number; brightness: number; saturate: number; scale: number };
  /** Strength of the vignette that darkens the frame edges, 0..1. */
  vignette: number;
  art: {
    radiusScale: number;
    /** How hard the artwork pumps with the bass. */
    pulse: number;
    /** Degrees of slow rotation. */
    sway: number;
    glow: number;
    ring?: boolean;
  };
  bars: { style: BarStyle; opacity: number; thickness: number; radiusScale: number };
  /** Black bars top and bottom, film style. */
  letterbox: boolean;
  grain: number;
  /** Multiplier on the intro spring; <1 is snappier, >1 is slower. */
  motion: number;
};

export const VIBES: Record<string, Vibe> = {
  hyperpop: {
    id: "hyperpop",
    label: "Hyperpop",
    blurb: "Candy colours, heavy caps, hard bass pump",
    fonts: { title: SANS, lyric: SANS },
    title: { weight: 900, transform: "uppercase", letterSpacing: "-0.02em" },
    artistLabel: { letterSpacing: "0.34em", weight: 800 },
    lyric: {
      weight: 900,
      transform: "uppercase",
      letterSpacing: "-0.01em",
      shadow: "0 0 26px rgba(255,60,180,0.55), 0 4px 22px rgba(0,0,0,0.6)",
      sizeScale: 1.04,
    },
    palette: { mode: "artwork", primary: "#ff4fd8", secondary: "#22dcf5" },
    background: "#12001f",
    backdrop: { blur: 55, brightness: 0.62, saturate: 2.1, scale: 2.4 },
    vignette: 0.55,
    art: { radiusScale: 0.06, pulse: 0.11, sway: 2.2, glow: 1.5, ring: true },
    bars: { style: "bars", opacity: 1, thickness: 0.72, radiusScale: 0.5 },
    letterbox: false,
    grain: 0,
    motion: 0.75,
  },

  anime: {
    id: "anime",
    label: "Dark anime",
    blurb: "Deep blacks, blood red, dramatic and still",
    fonts: { title: SANS, lyric: SANS },
    title: { weight: 800, transform: "uppercase", letterSpacing: "0.06em", italic: true },
    artistLabel: { letterSpacing: "0.42em", weight: 600 },
    lyric: {
      weight: 700,
      transform: "none",
      letterSpacing: "0.01em",
      italic: true,
      shadow: "0 3px 0 rgba(0,0,0,0.85), 0 0 34px rgba(255,40,60,0.35)",
      sizeScale: 0.98,
    },
    palette: { mode: "fixed", primary: "#ff2d46", secondary: "#8b1020" },
    background: "#05060a",
    backdrop: { blur: 80, brightness: 0.34, saturate: 1.15, scale: 2.6 },
    vignette: 0.92,
    art: { radiusScale: 0.015, pulse: 0.035, sway: 0.35, glow: 1.1, ring: true },
    bars: { style: "line", opacity: 0.85, thickness: 0.5, radiusScale: 0.2 },
    letterbox: true,
    grain: 0.055,
    motion: 1.35,
  },

  dreamy: {
    id: "dreamy",
    label: "Dreamy",
    blurb: "Soft pastels, glow, lowercase, floating",
    fonts: { title: SERIF, lyric: SERIF },
    title: { weight: 400, transform: "none", letterSpacing: "0.01em", italic: true },
    artistLabel: { letterSpacing: "0.3em", weight: 400 },
    lyric: {
      weight: 400,
      transform: "lowercase",
      letterSpacing: "0.02em",
      italic: true,
      shadow: "0 0 40px rgba(255,255,255,0.5), 0 4px 26px rgba(0,0,0,0.35)",
      sizeScale: 1.0,
    },
    palette: { mode: "artwork", primary: "#c9b8ff", secondary: "#ffc2e2" },
    background: "#171029",
    backdrop: { blur: 110, brightness: 0.75, saturate: 1.5, scale: 2.2 },
    vignette: 0.3,
    art: { radiusScale: 0.5, pulse: 0.03, sway: 2.6, glow: 2.0 },
    bars: { style: "dots", opacity: 0.6, thickness: 0.5, radiusScale: 0.5 },
    letterbox: false,
    grain: 0,
    motion: 1.5,
  },

  cinematic: {
    id: "cinematic",
    label: "Cinematic",
    blurb: "Letterboxed, muted, wide serif titles",
    fonts: { title: SERIF, lyric: SANS },
    title: { weight: 400, transform: "uppercase", letterSpacing: "0.18em" },
    artistLabel: { letterSpacing: "0.5em", weight: 400 },
    lyric: {
      weight: 300,
      transform: "none",
      letterSpacing: "0.04em",
      shadow: "0 2px 18px rgba(0,0,0,0.8)",
      sizeScale: 0.9,
    },
    palette: { mode: "fixed", primary: "#e8d5b0", secondary: "#2e6f86" },
    background: "#07090c",
    backdrop: { blur: 70, brightness: 0.4, saturate: 0.7, scale: 2.5 },
    vignette: 0.8,
    art: { radiusScale: 0.008, pulse: 0.02, sway: 0.2, glow: 0.5 },
    bars: { style: "line", opacity: 0.5, thickness: 0.35, radiusScale: 0 },
    letterbox: true,
    grain: 0.07,
    motion: 1.6,
  },

  reggae: {
    id: "reggae",
    label: "Reggae",
    blurb: "Warm golds and greens, round, bouncing",
    fonts: { title: SANS, lyric: SANS },
    title: { weight: 800, transform: "none", letterSpacing: "-0.01em" },
    artistLabel: { letterSpacing: "0.26em", weight: 700 },
    lyric: {
      weight: 700,
      transform: "none",
      letterSpacing: "0",
      shadow: "0 4px 0 rgba(0,0,0,0.5), 0 0 30px rgba(255,196,0,0.3)",
      sizeScale: 1.0,
    },
    palette: { mode: "fixed", primary: "#ffc400", secondary: "#1f9d55" },
    background: "#10140c",
    backdrop: { blur: 60, brightness: 0.6, saturate: 1.6, scale: 2.3 },
    vignette: 0.45,
    art: { radiusScale: 0.5, pulse: 0.09, sway: 1.6, glow: 1.2 },
    bars: { style: "dots", opacity: 0.95, thickness: 0.8, radiusScale: 0.5 },
    letterbox: false,
    grain: 0,
    motion: 0.85,
  },

  minimal: {
    id: "minimal",
    label: "Minimal",
    blurb: "Monochrome, thin type, almost no motion",
    fonts: { title: MONO, lyric: MONO },
    title: { weight: 400, transform: "uppercase", letterSpacing: "0.1em" },
    artistLabel: { letterSpacing: "0.4em", weight: 400 },
    lyric: {
      weight: 400,
      transform: "none",
      letterSpacing: "0.02em",
      shadow: "0 2px 14px rgba(0,0,0,0.7)",
      sizeScale: 0.86,
    },
    palette: { mode: "fixed", primary: "#f5f5f5", secondary: "#8a8a8a" },
    background: "#0a0a0a",
    backdrop: { blur: 90, brightness: 0.22, saturate: 0, scale: 2.2 },
    vignette: 0.5,
    art: { radiusScale: 0, pulse: 0.015, sway: 0, glow: 0.25 },
    bars: { style: "line", opacity: 0.4, thickness: 0.22, radiusScale: 0 },
    letterbox: false,
    grain: 0.03,
    motion: 1.8,
  },
};

export const DEFAULT_VIBE = "hyperpop";

export const VIBE_IDS = Object.keys(VIBES);

export function getVibe(id: string | null | undefined): Vibe {
  return (id && VIBES[id]) || VIBES[DEFAULT_VIBE];
}
