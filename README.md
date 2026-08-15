# ChorusFrame — stage-gate MVP

Landing page + waitlist + free sample-clip upload flow, plus a working
multi-format render pipeline. Next.js (App Router) + Tailwind + Supabase
+ Remotion.

> The folder is still named `verseframe` (the project's earlier name) so
> the existing Vercel link keeps working. Renaming it means re-linking
> the Vercel project.

## Run locally

```bash
npm install
npm run dev
```

Without Supabase keys the app runs in **demo mode**: forms validate and
succeed, but nothing is persisted (a warning is logged server-side).

## Connect Supabase (one-time, ~5 minutes)

1. Create a free project at https://supabase.com
2. Dashboard → **SQL Editor** → paste and run `supabase/schema.sql`
   (creates `waitlist` + `submissions` tables and the private
   `submissions` storage bucket)
3. Dashboard → **Project Settings → API** → copy the Project URL and
   the `service_role` key
4. `cp .env.local.example .env.local` and fill both values in
5. Restart the dev server

## Deploy to Vercel

1. Push this repo to GitHub
2. Import it in Vercel
3. Add the same two env vars in Vercel → Project → Settings →
   Environment Variables
4. Deploy

## Reviewing submissions

Stage-gate is intentionally manual: check the `submissions` table in
the Supabase dashboard (Table Editor), render a sample clip (below),
email it back, and set the row's `status` to `delivered`.
Instrument later — validate first.

## Rendering clips (Remotion)

`remotion/` holds one composition rendered at three sizes, so a change to
the look lands in every format at once:

| Format     | Composition id     | Size      | Used for                     |
| ---------- | ------------------ | --------- | ---------------------------- |
| `vertical` | `SampleClip`       | 1080×1920 | TikTok, Reels, Shorts, Canvas |
| `square`   | `SampleClipSquare` | 1080×1080 | Feed posts, carousels        |
| `wide`     | `SampleClipWide`   | 1920×1080 | YouTube                      |

Layout comes from `remotion/layout.ts` (positions derived from the canvas
size); accent colors come from `remotion/palette.ts`, which samples the
cover art and falls back to brand colors when the artwork is missing,
unreadable, or greyscale.

```bash
npm run studio            # preview/tweak any format in Remotion Studio
npm run render:clip       # render the built-in demo to out/clip.mp4
```

Render a real submission straight from Supabase:

```bash
npm run render:submission -- --latest
npm run render:campaign -- --latest --upload   # all three formats, uploaded
```

- `--latest` picks the newest `queued` submission; or pass a submission id
- `--formats vertical,square,wide` (or `all`) — default is `vertical`
- `--start 34 --duration 30` chooses the clip window (defaults: 0, 15s)
- `--no-end-card` drops the "Made with ChorusFrame" outro
- `--brand-colors` ignores the cover art and uses brand accents
- `--upload` pushes each MP4 to the public `clips` bucket and sets the
  row to `status=clip_ready` + `sample_clip_url`

The clip window is validated against the real song length at render time:
a `--start` past the end fails loudly, and a `--duration` that overruns is
clamped to the audio that actually exists.

`sample_clip_url` holds one URL (the vertical cut when present). All
uploaded formats are printed at the end of the run — the row needs a
JSON column before it can carry the full set.

Status lifecycle: `queued` → `in_progress` (claimed by a render run;
reverts to `queued` if the render fails or isn't uploaded) → `clip_ready`
(clip uploaded) → `delivered` (you emailed the artist — set manually).

## What's intentionally NOT here

No auth, no projects, no billing, no editor, no queue. Several of the
priority-one features (autosave, credit accounting, refund-on-failure,
export queue) need that substrate first. Those come after the stage
gate: ≥50 beta commitments, 10 repeat users, output quality that beats
current templates.
