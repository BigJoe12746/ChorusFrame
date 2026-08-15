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
the Supabase dashboard (Table Editor), download files from the
`submissions` storage bucket, build the sample clip, email it back, and
set the row's `status` to `delivered`. Instrument later — validate first.

## What's intentionally NOT here

No auth, no billing, no editor, no render pipeline. Those come after
the stage gate: ≥50 beta commitments, 10 repeat users, output quality
that beats current templates.
