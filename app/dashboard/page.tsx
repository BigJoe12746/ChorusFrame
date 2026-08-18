import Link from "next/link";
import Logo from "@/components/Logo";
import RenderControls, { type RenderJob } from "@/components/RenderControls";
import SetPassword from "@/components/SetPassword";
import BrandKit from "@/components/BrandKit";
import ShareLink from "@/components/ShareLink";
import DeleteSong from "@/components/DeleteSong";
import { getPlan } from "@/lib/plans";
import type { TimedLine } from "@/components/LyricTimingEditor";
import { getSupabaseAdmin, getSupabaseServer } from "@/lib/supabase";

export const dynamic = "force-dynamic";

type Submission = {
  id: string;
  song_title: string;
  artist_name: string | null;
  status: string;
  created_at: string;
  artwork_path: string | null;
  song_path: string;
  sample_clip_url: string | null;
  vibe: string | null;
  lyrics: string | null;
};

const STATUS: Record<string, { label: string; cls: string }> = {
  queued: { label: "In the queue", cls: "border-borderline text-muted" },
  in_progress: { label: "Rendering", cls: "border-blue text-blue" },
  clip_ready: { label: "Clips ready", cls: "border-cyan text-cyan" },
  delivered: { label: "Delivered", cls: "border-cyan text-cyan" },
};

const FORMAT_LABELS: Record<string, string> = {
  "sample-vertical.mp4": "9:16 vertical",
  "sample-square.mp4": "1:1 square",
  "sample-wide.mp4": "16:9 wide",
  "sample.mp4": "Clip",
};

export default async function DashboardPage({ searchParams }: PageProps<"/dashboard">) {
  // Set when an artist has just uploaded: open that song's picker for them
  // rather than leaving them to work out that a button exists.
  const justUploaded = String((await searchParams)?.new ?? "");
  const supabase = await getSupabaseServer();
  if (!supabase) {
    return (
      <main className="mx-auto w-full max-w-3xl flex-1 px-6 py-20 text-center">
        <p className="text-muted">Sign-in isn&apos;t configured on this deployment.</p>
      </main>
    );
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();

  // RLS scopes this to the signed-in artist's own rows
  const { data, error } = await supabase
    .from("submissions")
    .select(
      "id, song_title, artist_name, status, created_at, artwork_path, song_path, sample_clip_url, vibe, lyrics"
    )
    .order("created_at", { ascending: false });
  const submissions = (data ?? []) as Submission[];

  // Newest job per song, so each row can show its own render state.
  // RLS scopes this to the artist's own jobs.
  const { data: jobRows } = await supabase
    .from("render_jobs")
    .select("id, submission_id, status, formats, attempts, max_attempts, error, clip_urls")
    .order("created_at", { ascending: false });
  const latestJob = new Map<string, RenderJob>();
  for (const j of (jobRows ?? []) as (RenderJob & { submission_id: string })[]) {
    if (!latestJob.has(j.submission_id)) latestJob.set(j.submission_id, j);
  }

  /*
   * Beat grids sit behind a migration that may not have been run yet, so this
   * is a separate query that is allowed to fail. Selecting these columns in the
   * main query took the entire dashboard down with "column submissions.bpm does
   * not exist" — a missing optional feature must never cost an artist the page.
   */
  const beatGrids = new Map<string, { bpm: number; offset: number }>();
  const savedTimings = new Map<string, TimedLine[]>();
  {
    const { data: grids } = await supabase
      .from("submissions")
      .select("id, bpm, beat_offset, lyrics_timing");
    for (const g of (grids ?? []) as {
      id: string;
      bpm: number | null;
      beat_offset: number | null;
      lyrics_timing: TimedLine[] | null;
    }[]) {
      if (Array.isArray(g.lyrics_timing) && g.lyrics_timing.length) {
        savedTimings.set(g.id, g.lyrics_timing);
      }
      if (g.bpm != null && g.beat_offset != null) {
        beatGrids.set(g.id, { bpm: Number(g.bpm), offset: Number(g.beat_offset) });
      }
    }
  }

  // The artist's saved brand kit. RLS scopes this to their own row, and a
  // missing profile (or an unrun migration) simply means no kit.
  const { data: profile } = await supabase
    .from("profiles")
    .select("plan, brand_primary, brand_secondary, brand_font")
    .eq("id", user?.id ?? "")
    .maybeSingle();

  // Artwork lives in a private bucket, and finished clips may exist in several
  // formats — resolve both with the service-role client.
  // What this artist may actually ask for, so the controls cannot offer a
  // choice the API will reject.
  const plan = getPlan(profile?.plan);

  const admin = getSupabaseAdmin();
  const artThumbs = new Map<string, string>();
  const audioUrls = new Map<string, string>();
  const clipFiles = new Map<string, { name: string; url: string }[]>();

  if (admin) {
    await Promise.all(
      submissions.map(async (s) => {
        if (s.artwork_path) {
          const { data: signed } = await admin.storage
            .from("submissions")
            .createSignedUrl(s.artwork_path, 3600);
          if (signed) artThumbs.set(s.id, signed.signedUrl);
        }
        // The hook picker decodes this in the browser to draw the waveform
        if (s.song_path) {
          const { data: signedAudio } = await admin.storage
            .from("submissions")
            .createSignedUrl(s.song_path, 3600);
          if (signedAudio) audioUrls.set(s.id, signedAudio.signedUrl);
        }
        const { data: files } = await admin.storage.from("clips").list(s.id);
        if (files?.length) {
          clipFiles.set(
            s.id,
            files
              .filter((f) => f.name.endsWith(".mp4"))
              .map((f) => ({
                name: f.name,
                url: admin.storage.from("clips").getPublicUrl(`${s.id}/${f.name}`).data.publicUrl,
              }))
          );
        }
      })
    );
  }

  return (
    <main className="mx-auto w-full max-w-5xl flex-1 px-6">
      <header className="flex items-center justify-between py-6">
        <Link href="/">
          <Logo size={26} />
        </Link>
        <div className="flex items-center gap-4 text-sm">
          <Link href="/upload" className="text-muted transition hover:text-foreground">
            New upload
          </Link>
          <form action="/auth/signout" method="post">
            <button type="submit" className="text-muted transition hover:text-foreground">
              Sign out
            </button>
          </form>
        </div>
      </header>

      <section className="py-8">
        <h1 className="text-3xl font-bold tracking-tight">Your songs</h1>
        <div className="mt-2 flex flex-wrap items-baseline gap-x-3 gap-y-1">
          <p className="text-sm text-muted">Signed in as {user?.email}</p>
          <SetPassword
            hasPassword={Boolean(
              (user?.identities ?? []).some((i) => i.provider === "email") &&
                user?.user_metadata?.has_password
            )}
          />
        </div>

        {/* A kit belongs to the artist, not to a song, so it lives up here */}
        <div className="mt-4">
          <BrandKit
            initial={{
              primary: profile?.brand_primary ?? null,
              secondary: profile?.brand_secondary ?? null,
              font: profile?.brand_font ?? null,
            }}
          />
        </div>

        {error ? (
          <p className="mt-8 rounded-xl border border-borderline bg-surface p-4 text-sm text-danger">
            Could not load your uploads: {error.message}
          </p>
        ) : null}

        {submissions.length === 0 ? (
          <div className="mt-8 rounded-2xl border border-borderline bg-surface p-10 text-center">
            <p className="text-4xl">🎵</p>
            <h2 className="mt-4 text-lg font-semibold">Nothing here yet</h2>
            <p className="mx-auto mt-2 max-w-sm text-sm text-muted">
              Send us a song and we&apos;ll build your first clip. It shows up
              here when it&apos;s ready.
            </p>
            <Link
              href="/upload"
              className="brand-gradient mt-6 inline-block rounded-xl px-6 py-3 text-sm font-semibold text-white transition hover:opacity-90"
            >
              Upload a song
            </Link>
          </div>
        ) : (
          <ul className="mt-8 flex flex-col gap-4">
            {submissions.map((s) => {
              const badge = STATUS[s.status] ?? {
                label: s.status,
                cls: "border-borderline text-muted",
              };
              const clips = clipFiles.get(s.id) ?? [];
              const thumb = artThumbs.get(s.id);
              return (
                <li
                  key={s.id}
                  className="flex flex-col gap-4 rounded-2xl border border-borderline bg-surface p-5 sm:flex-row sm:items-center"
                >
                  <div className="h-16 w-16 shrink-0 overflow-hidden rounded-xl border border-borderline bg-surface-raised">
                    {thumb ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={thumb} alt="" className="h-full w-full object-cover" />
                    ) : (
                      <div className="flex h-full w-full items-center justify-center text-xl text-muted">
                        ♪
                      </div>
                    )}
                  </div>

                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold">{s.song_title}</p>
                    <p className="mt-0.5 text-xs text-muted">
                      {new Date(s.created_at).toLocaleDateString(undefined, {
                        year: "numeric",
                        month: "short",
                        day: "numeric",
                      })}
                    </p>
                    {clips.length > 0 ? (
                      <div className="mt-2 flex flex-wrap items-center gap-2">
                        <ShareLink submissionId={s.id} />
                        {clips.map((c) => (
                          <a
                            key={c.name}
                            href={c.url}
                            target="_blank"
                            rel="noreferrer"
                            className="rounded-lg border border-borderline px-2.5 py-1 text-xs text-muted transition hover:border-cyan hover:text-foreground"
                          >
                            {FORMAT_LABELS[c.name] ?? c.name} ↗
                          </a>
                        ))}
                      </div>
                    ) : null}
                    <div className="mt-3">
                      <RenderControls
                        submissionId={s.id}
                        initialJob={latestJob.get(s.id) ?? null}
                        initialVibe={s.vibe}
                        audioUrl={audioUrls.get(s.id) ?? null}
                        artworkUrl={artThumbs.get(s.id) ?? null}
                        songTitle={s.song_title}
                        artistName={s.artist_name ?? ""}
                        lyrics={s.lyrics ?? ""}
                        beatGrid={beatGrids.get(s.id) ?? null}
                        savedTimings={savedTimings.get(s.id) ?? []}
                        maxClipSeconds={plan.maxClipSeconds}
                        planName={plan.name}
                        autoOpen={s.id === justUploaded}
                      />
                    </div>
                  </div>

                  <div className="flex shrink-0 flex-col items-end gap-2 self-start sm:self-center">
                    <span
                      className={`rounded-full border px-3 py-1 text-xs ${badge.cls}`}
                    >
                      {badge.label}
                    </span>
                    <DeleteSong
                      submissionId={s.id}
                      songTitle={s.song_title}
                      clipCount={clips.length}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </main>
  );
}
