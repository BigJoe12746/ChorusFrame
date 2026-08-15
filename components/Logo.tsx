import { useId } from "react";

/** ChorusFrame mark: video frame + waveform + play triangle. */
export function LogoMark({ size = 30 }: { size?: number }) {
  const id = useId();
  return (
    <svg
      width={size}
      height={(size * 48) / 64}
      viewBox="0 0 64 48"
      fill="none"
      aria-hidden
    >
      <defs>
        <linearGradient id={`${id}-frame`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="var(--cyan)" />
          <stop offset="100%" stopColor="var(--blue)" />
        </linearGradient>
      </defs>
      <rect
        x="3.5"
        y="3.5"
        width="57"
        height="41"
        rx="12"
        stroke={`url(#${id}-frame)`}
        strokeWidth="6"
      />
      <path
        d="M13 24h4.5l3-9.5 4 18.5 3.5-13 2.5 8 3-4H51"
        stroke={`url(#${id}-frame)`}
        strokeWidth="3"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M29.5 17L43 24l-13.5 7V17Z" fill="var(--violet-strong)" />
    </svg>
  );
}

export default function Logo({ size = 30 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-2.5">
      <LogoMark size={size} />
      <span className="brand-text text-lg font-extrabold tracking-tight">
        ChorusFrame
      </span>
    </span>
  );
}
