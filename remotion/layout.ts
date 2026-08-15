// One project, every format.
//
// The same composition renders vertical (9:16), square (1:1), and wide (16:9)
// by reading a layout derived from the canvas size — no per-format template to
// maintain, so a change to the look lands in every export at once.

export type ClipFormat = "vertical" | "square" | "wide";

export type ClipLayout = {
  format: ClipFormat;
  /** Type scale base — the short edge, so text reads the same size in every format. */
  unit: number;
  art: { size: number; left: number; top: number; radius: number };
  header: {
    top: number;
    left: number;
    width: number;
    align: "center" | "left";
    titleSize: number;
    artistSize: number;
  };
  lyric: {
    top: number;
    left: number;
    width: number;
    size: number;
    align: "center" | "left";
    maxHeight: number;
  };
  bars: { top: number; left: number; width: number; height: number; count: number };
  watermark: { top: number; left: number; width: number; size: number };
  progressHeight: number;
};

export function formatOf(width: number, height: number): ClipFormat {
  if (width > height) return "wide";
  return height / width > 1.3 ? "vertical" : "square";
}

export function getLayout(width: number, height: number): ClipLayout {
  const format = formatOf(width, height);
  const unit = Math.min(width, height);
  const titleSize = unit * 0.0667;
  const artistSize = unit * 0.0315;
  const lyricSize = unit * 0.0519;
  const progressHeight = Math.max(4, Math.round(unit * 0.0074));

  if (format === "wide") {
    const pad = width * 0.055;
    const artSize = height * 0.58;
    const artTop = (height - artSize) / 2;
    const colLeft = pad + artSize + width * 0.047;
    const colWidth = width - colLeft - pad;
    const barsHeight = height * 0.14;
    return {
      format,
      unit,
      art: { size: artSize, left: pad, top: artTop, radius: artSize * 0.05 },
      header: {
        top: artTop + height * 0.02,
        left: colLeft,
        width: colWidth,
        align: "left",
        titleSize,
        artistSize,
      },
      lyric: {
        top: artTop + artSize * 0.5,
        left: colLeft,
        width: colWidth,
        size: lyricSize,
        align: "left",
        maxHeight: height * 0.22,
      },
      bars: {
        top: height - height * 0.08 - barsHeight,
        left: colLeft,
        width: colWidth,
        height: barsHeight,
        count: 28,
      },
      watermark: { top: height - height * 0.09, left: pad, width: artSize, size: unit * 0.026 },
      progressHeight,
    };
  }

  if (format === "square") {
    const artSize = height * 0.33;
    const barsHeight = height * 0.1;
    return {
      format,
      unit,
      art: {
        size: artSize,
        left: (width - artSize) / 2,
        top: height * 0.26,
        radius: artSize * 0.05,
      },
      header: {
        top: height * 0.055,
        left: width * 0.083,
        width: width * 0.834,
        align: "center",
        titleSize,
        artistSize,
      },
      lyric: {
        top: height * 0.62,
        left: width * 0.1,
        width: width * 0.8,
        size: lyricSize,
        align: "center",
        maxHeight: height * 0.13,
      },
      bars: {
        top: height - height * 0.085 - barsHeight,
        left: width * 0.11,
        width: width * 0.78,
        height: barsHeight,
        count: 32,
      },
      watermark: { top: height - height * 0.06, left: 0, width, size: unit * 0.026 },
      progressHeight,
    };
  }

  // vertical (9:16) — the primary format
  const artSize = width * 0.667;
  const barsHeight = height * 0.104;
  return {
    format,
    unit,
    art: {
      size: artSize,
      left: (width - artSize) / 2,
      top: height * 0.25,
      radius: artSize * 0.05,
    },
    header: {
      top: height * 0.078,
      left: width * 0.083,
      width: width * 0.834,
      align: "center",
      titleSize,
      artistSize,
    },
    lyric: {
      top: height * 0.682,
      left: width * 0.102,
      width: width * 0.796,
      size: lyricSize,
      align: "center",
      maxHeight: height * 0.109,
    },
    bars: {
      top: height - height * 0.099 - barsHeight,
      left: width * 0.111,
      width: width * 0.778,
      height: barsHeight,
      count: 32,
    },
    watermark: { top: height - height * 0.062, left: 0, width, size: unit * 0.026 },
    progressHeight,
  };
}
