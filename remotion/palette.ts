// Cover-art color extraction.
//
// Artists get clips themed to their own artwork instead of our brand colors.
// Runs in the browser (Remotion renders in headless Chrome), so it needs no
// native image decoding. Falls back to brand colors whenever the artwork is
// missing, unreadable, or too washed out to theme with.

export type Palette = {
  primary: string;
  secondary: string;
  /** true when the colors came from the artwork rather than the brand fallback */
  fromArtwork: boolean;
};

export const BRAND_PALETTE: Palette = {
  primary: "#22dcf5", // electric cyan
  secondary: "#7c3aed", // electric violet
  fromArtwork: false,
};

function rgbToHsl(r: number, g: number, b: number) {
  r /= 255;
  g /= 255;
  b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  if (max === min) return { h: 0, s: 0, l };
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h: number;
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  else if (max === g) h = ((b - r) / d + 2) / 6;
  else h = ((r - g) / d + 4) / 6;
  return { h: h * 360, s, l };
}

function hslToHex(h: number, s: number, l: number) {
  h = ((h % 360) + 360) % 360;
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  let rgb: [number, number, number];
  if (h < 60) rgb = [c, x, 0];
  else if (h < 120) rgb = [x, c, 0];
  else if (h < 180) rgb = [0, c, x];
  else if (h < 240) rgb = [0, x, c];
  else if (h < 300) rgb = [x, 0, c];
  else rgb = [c, 0, x];
  const to255 = (v: number) =>
    Math.round((v + m) * 255)
      .toString(16)
      .padStart(2, "0");
  return `#${to255(rgb[0])}${to255(rgb[1])}${to255(rgb[2])}`;
}

/**
 * Normalize an extracted hue into something that reads clearly as an accent
 * on a near-black background: saturated, mid-light, never muddy.
 */
function asAccent(h: number, s: number) {
  return hslToHex(h, Math.min(0.92, Math.max(0.62, s)), 0.6);
}

const BUCKETS = 18; // 20° per bucket

/** Sample an already-loaded image and pick two complementary accent colors. */
export function extractPalette(img: HTMLImageElement): Palette | null {
  let data: Uint8ClampedArray;
  try {
    const size = 48;
    const canvas = document.createElement("canvas");
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    if (!ctx) return null;
    ctx.drawImage(img, 0, 0, size, size);
    // Throws a SecurityError if the artwork host didn't allow cross-origin reads
    data = ctx.getImageData(0, 0, size, size).data;
  } catch {
    return null;
  }

  const score = new Array(BUCKETS).fill(0);
  const satSum = new Array(BUCKETS).fill(0);
  const count = new Array(BUCKETS).fill(0);
  const hueSin = new Array(BUCKETS).fill(0);
  const hueCos = new Array(BUCKETS).fill(0);

  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] < 128) continue; // transparent
    const { h, s, l } = rgbToHsl(data[i], data[i + 1], data[i + 2]);
    // Ignore near-greys and the extremes: they carry no usable hue
    if (s < 0.18 || l < 0.12 || l > 0.92) continue;
    const b = Math.min(BUCKETS - 1, Math.floor((h / 360) * BUCKETS));
    const weight = s * (1 - Math.abs(l - 0.55)); // favour vivid, mid-light pixels
    score[b] += weight;
    satSum[b] += s;
    count[b] += 1;
    const rad = (h * Math.PI) / 180;
    hueSin[b] += Math.sin(rad) * weight;
    hueCos[b] += Math.cos(rad) * weight;
  }

  const total = score.reduce((a, b) => a + b, 0);
  if (total < 12) return null; // essentially greyscale artwork — keep brand colors

  const bucketHue = (b: number) => {
    const deg = (Math.atan2(hueSin[b], hueCos[b]) * 180) / Math.PI;
    return (deg + 360) % 360;
  };
  const bucketSat = (b: number) => (count[b] > 0 ? satSum[b] / count[b] : 0.7);

  let best = 0;
  for (let b = 1; b < BUCKETS; b++) if (score[b] > score[best]) best = b;

  const primaryHue = bucketHue(best);

  // Secondary: the strongest hue at least 60° away, so the two accents are
  // visibly different. Falls back to a fixed offset when the art is monochrome.
  let second = -1;
  for (let b = 0; b < BUCKETS; b++) {
    if (score[b] <= 0) continue;
    // Angular distance on the hue wheel; skip anything too close to the primary
    const delta = Math.abs(((bucketHue(b) - primaryHue + 540) % 360) - 180);
    if (delta < 60) continue;
    if (second === -1 || score[b] > score[second]) second = b;
  }

  const primary = asAccent(primaryHue, bucketSat(best));
  const secondary =
    second === -1
      ? asAccent(primaryHue + 140, 0.75)
      : asAccent(bucketHue(second), bucketSat(second));

  return { primary, secondary, fromArtwork: true };
}
