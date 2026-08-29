/**
 * Positioning against the category, without naming anyone.
 *
 * Competitor names stay out of ChorusFrame's copy as a standing rule, so this
 * compares against the *shape* of the alternatives an artist is actually
 * choosing between. That's also the more honest comparison: the claim isn't
 * "cheaper than product X", it's that a general editor charges you to make one
 * video at a time while this makes the set.
 */
const ROWS: { label: string; general: string; us: string; better: boolean }[] = [
  {
    label: "Typical price",
    general: "$15–25 a month",
    us: "$10 a month",
    better: true,
  },
  {
    label: "What you start from",
    general: "An empty timeline",
    us: "Your song, already read for tempo and hooks",
    better: true,
  },
  {
    label: "Getting every format",
    general: "Re-crop and re-export each one",
    us: "9:16, 1:1 and 16:9 from one project",
    better: true,
  },
  {
    label: "Lyric timing",
    general: "Place every line by hand on a timeline",
    us: "Tap along once, then nudge",
    better: true,
  },
  {
    label: "Look and feel",
    general: "General-purpose templates",
    us: "Ten directions built for music releases",
    better: true,
  },
  {
    label: "Your brand across releases",
    general: "Re-apply it every time",
    us: "Saved once, on every render",
    better: true,
  },
  {
    label: "Deep frame-level editing",
    general: "Yes — that's what they're for",
    us: "No, and deliberately not",
    better: false,
  },
];

export default function PricingCompare() {
  return (
    <section className="pb-16">
      <h2 className="text-center text-3xl font-bold tracking-tight sm:text-4xl">
        Why not just use a video editor?
      </h2>
      <p className="mx-auto mt-3 max-w-2xl text-center text-muted">
        You can. A general editor will do anything — which is exactly the
        problem when you have a release on Friday and eight decisions to make
        per clip. This does one job.
      </p>

      <div className="mx-auto mt-8 max-w-3xl overflow-x-auto">
        <table className="w-full min-w-[34rem] border-collapse text-sm">
          <thead>
            <tr className="border-b border-borderline text-left">
              <th className="py-3 pr-4 font-medium text-muted"> </th>
              <th className="py-3 pr-4 font-medium text-muted">
                A general video editor
              </th>
              <th className="py-3 font-semibold">ChorusFrame</th>
            </tr>
          </thead>
          <tbody>
            {ROWS.map((r) => (
              <tr key={r.label} className="border-b border-borderline align-top">
                <th scope="row" className="py-3 pr-4 text-left font-medium">
                  {r.label}
                </th>
                <td className="py-3 pr-4 text-muted">{r.general}</td>
                <td className={`py-3 ${r.better ? "text-foreground" : "text-muted"}`}>
                  {r.us}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Saying what it is NOT is what makes the rest believable */}
      <p className="mx-auto mt-6 max-w-2xl text-center text-sm text-muted">
        If you want to cut frame by frame, colour grade, or edit a podcast, use
        an editor — genuinely. This is for turning a finished song into the
        clips a release needs, and it&apos;s priced at about half what a
        general tool costs because it does far less, on purpose.
      </p>
    </section>
  );
}
