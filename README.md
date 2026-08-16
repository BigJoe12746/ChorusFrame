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

## Artist accounts (Supabase Auth)

Passwordless email links — no password handling anywhere in the codebase.

One-time setup, after `schema.sql`:

1. SQL Editor → run `supabase/002_auth.sql` (adds `submissions.user_id`,
   a `profiles` table with a signup trigger, and RLS read policies)
2. Project Settings → **API Keys** → copy the **publishable** key into
   `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
3. Authentication → **URL Configuration** → add redirect URLs:
   `http://localhost:3000/**` and your production URL + `/**`

Until the publishable key is set, sign-in is disabled with a clear
message and the rest of the site works normally.

Routes: `/login` (magic link) → `/auth/callback` (code exchange) →
`/dashboard` (the artist's own uploads and finished clips).
`middleware.ts` refreshes the session and gates `/dashboard`.

Uploads made while signed in are attributed to the account; anonymous
free-sample uploads keep `user_id` null and stay service-role-only.

## Self-serve rendering (the queue)

Artists start their own renders from `/dashboard`; a worker process does the
work. Nothing in the web app knows where the worker runs.

One-time setup: SQL Editor → run `supabase/003_render_queue.sql`.

```bash
npm run worker        # poll for jobs forever  (Ctrl-C releases the current job)
npm run worker:once   # drain the queue and exit
```

**In production the worker runs on Railway** (project `chorusframe-worker`,
service `worker`), built from `Dockerfile.worker` — a Node image with Chrome's
shared libraries and the headless shell baked in at build time. It needs no
inbound networking and exposes no ports; it only talks out to Supabase.

```bash
npx @railway/cli up --service worker --ci      # deploy
npx @railway/cli logs --service worker          # tail it
```

Railway variables required: `NEXT_PUBLIC_SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY`, `NEXT_PUBLIC_SITE_URL`. There is no `.env.local`
in the image — `loadEnv()` falls back to the process environment.

Two things the image genuinely needs and will fail without: `tsconfig.json`
(the Remotion CLI refuses to start without one) and the Chrome shared
libraries installed via apt.

Running a local worker at the same time as the Railway one is fine — they
claim different jobs.

Run several workers if you want more throughput — `claim_render_job()` uses
`FOR UPDATE SKIP LOCKED`, so they take different jobs instead of colliding.
The worker heartbeats while rendering; a job whose worker dies is requeued
automatically, up to `max_attempts`.

Which state lives where:

| Table                | Owns                                                 |
| -------------------- | ---------------------------------------------------- |
| `render_jobs.status` | the render lifecycle: queued → rendering → done/failed |
| `submissions.status` | the delivery lifecycle: queued → clip_ready → delivered |

The worker only ever advances a submission to `clip_ready` on success — it
never demotes one, so a failed re-render can't undo a delivered song.

Quotas (`app/api/render/route.ts`): 5 renders per artist per 24h, counting
only jobs that weren't failures, because the marketing page promises failed
renders never cost anything. A separate ceiling of 25 counts every job
including failures, purely to stop a deliberate failure loop from burning
compute. Both are enforced inside `enqueue_render_job()` in the same
transaction as the insert, so concurrent requests can't slip past them.

## Vibes

Six visual directions in `remotion/vibes.ts`: `hyperpop`, `anime`, `dreamy`,
`cinematic`, `reggae`, `minimal`. A vibe is not a colour swap — it changes
typography (family, weight, case, tracking), motion speed, bass-pulse depth,
the *shape* of the visualizer (bars / dots / trace / none), artwork treatment
(corner radius, ring, glow), backdrop blur and saturation, vignette,
letterbox, and film grain.

A vibe declares whether its palette is `artwork` (themed from the cover) or
`fixed` (keeps its own identity whatever the cover looks like) — that's the
point of picking "dark anime" over "dreamy".

Artists choose on the dashboard before rendering; the choice is remembered on
the song and carried through the queue on the job, so a render always uses
what was picked at the time. An unknown id falls back to the default rather
than failing the render.

Add one by adding an entry to `VIBES` and to `VALID_VIBES` in
`app/api/render/route.ts` (kept in step deliberately, so the API rejects ids
the renderer doesn't know). Font stacks stay on families present both locally
and in the worker image (`fonts-liberation`).

## Telling the artist their clips are done

`scripts/lib/notify.mjs` emails the artist when a render finishes — self-serve
isn't self-serve if they have to watch the dashboard. Set `RESEND_API_KEY` or
`POSTMARK_TOKEN` on the **worker** (plus `NOTIFY_FROM` once you have a verified
sender). With neither, the worker logs what it would have sent.

Sending never fails a job: the clips exist whether or not the email lands.

## Lyric timing

"Paste your real lyrics — timing is our job" is a promise on the landing
page, so lines are placed where they are actually sung rather than spread
evenly across the clip.

How it works: a transcriber returns what it *heard* with word-level
timestamps, and `scripts/lib/align.mjs` aligns those words to the artist's
official lyrics (Needleman-Wunsch with fuzzy word matching). We never show
the transcript — only its timings. That survives the ways transcription
actually fails: a misheard word still matches, a dropped word is
interpolated between its neighbours, and a whole missed line lands between
the lines around it.

```bash
npm run test:align   # 38 assertions, including misheard/dropped/missing-line cases
```

Set `OPENAI_API_KEY` (Whisper) or `DEEPGRAM_API_KEY` on the **worker** to turn
it on. Without one, timing falls back to a syllable-weighted spread — long
lines hold the screen longer than short ones, which is the main thing even
distribution gets wrong — and is labelled `estimated`.

Real timing is cached on `submissions.lyrics_timing` (migration
`supabase/004_lyric_timing.sql`) so re-rendering another window or format
doesn't pay for transcription twice. Estimates are deliberately **not**
cached, so every song upgrades itself the moment a key is configured — no
backfill needed. A transcription failure never fails a render; it falls back
to an estimate, because an estimated clip beats no clip.

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
