# VerseFrame — stage-gate MVP

Landing page + waitlist + free sample-clip upload flow, per the 30-day
validation plan. Next.js (App Router) + Tailwind + Supabase.

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

## Rendering sample clips (Remotion)

The `remotion/` folder holds the SampleClip template: a 1080×1920
audio-reactive visualizer (blurred-artwork backdrop, bass-pulsing cover
card, timed lyric lines, spectrum bars, VerseFrame end card).

```bash
npm run studio            # open Remotion Studio to preview/tweak the template
npm run render:clip       # render the built-in demo to out/clip.mp4
```

Render a real submission straight from Supabase:

```bash
npm run render:submission -- --latest
```

- `--latest` picks the newest `queued` submission; or pass a submission id
- `--start 34 --duration 30` chooses the clip window (defaults: 0, 15s)
- `--no-end-card` drops the "Made with VerseFrame" outro
- `--upload` pushes the MP4 to the public `clips` bucket and sets the
  row to `status=clip_ready` + `sample_clip_url`

Status lifecycle: `queued` → `in_progress` (claimed by a render run;
reverts to `queued` if the render fails or isn't uploaded) → `clip_ready`
(clip uploaded) → `delivered` (you emailed the artist — set manually).

## What's intentionally NOT here

No auth, no billing, no editor, no render pipeline. Those come after
the stage gate: ≥50 beta commitments, 10 repeat users, output quality
that beats current templates.
