import { ImageResponse } from "next/og";

export const alt = "ChorusFrame — upload one song, get your release clips";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OgImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 28,
          background: "linear-gradient(135deg, #080b16 0%, #12102a 55%, #1c1440 100%)",
          color: "#eef0f8",
          fontFamily: "Arial",
        }}
      >
        <svg width="200" height="150" viewBox="0 0 64 48" fill="none">
          <rect x="3.5" y="3.5" width="57" height="41" rx="12" stroke="#22dcf5" strokeWidth="6" />
          <path
            d="M13 24h4.5l3-9.5 4 18.5 3.5-13 2.5 8 3-4H51"
            stroke="#2b8cff"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <path d="M29.5 17L43 24l-13.5 7V17Z" fill="#7c3aed" />
        </svg>
        <div style={{ display: "flex", fontSize: 72, fontWeight: 700 }}>ChorusFrame</div>
        <div style={{ display: "flex", fontSize: 30, color: "#8b93b5" }}>
          Upload one song. Get your release clips.
        </div>
      </div>
    ),
    size
  );
}
