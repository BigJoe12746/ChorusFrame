/**
 * What state a song is actually in, at a glance.
 *
 * A row used to show a title, a date and a status badge, which said nothing
 * about whether the song was ready to make a good clip. These are the four
 * things that decide that: whether it has words, whether those words are
 * timed, whether we know the tempo, and what has been produced so far.
 */
export default function SongMeta({
  hasLyrics,
  timingSource,
  bpm,
  clipCount,
}: {
  hasLyrics: boolean;
  timingSource: string | null;
  bpm: number | null;
  clipCount: number;
}) {
  const chips: { text: string; tone: "good" | "todo" }[] = [];

  chips.push(
    hasLyrics
      ? { text: "Lyrics added", tone: "good" }
      : { text: "No lyrics — visualizer only", tone: "todo" }
  );

  if (hasLyrics) {
    if (timingSource === "manual") chips.push({ text: "Timed by ear", tone: "good" });
    else if (timingSource && timingSource !== "estimated")
      chips.push({ text: "Auto-aligned", tone: "good" });
    else chips.push({ text: "Timing not set", tone: "todo" });
  }

  if (bpm) chips.push({ text: `${Math.round(bpm)} BPM`, tone: "good" });

  if (clipCount > 0) {
    chips.push({ text: `${clipCount} clip${clipCount === 1 ? "" : "s"}`, tone: "good" });
  }

  return (
    <ul className="mt-2 flex flex-wrap gap-1.5">
      {chips.map((c) => (
        <li
          key={c.text}
          className={`rounded-full border px-2 py-0.5 text-[11px] ${
            c.tone === "good"
              ? "border-borderline text-muted"
              : "border-danger/40 text-danger"
          }`}
        >
          {c.text}
        </li>
      ))}
    </ul>
  );
}
