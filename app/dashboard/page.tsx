import Link from "next/link";
import RenderControls, { type RenderJob } from "@/components/RenderControls";
import SiteHeader from "@/components/SiteHeader";
import SetPassword from "@/components/SetPassword";
import BrandKit from "@/components/BrandKit";
import ShareLink from "@/components/ShareLink";
import DeleteSong from "@/components/DeleteSong";
import LibraryStats from "@/components/LibraryStats";
import SongMeta from "@/components/SongMeta";
import { getPlan } from "@/lib/plans";
import type { TimedLine } from "@/components/LyricTimingEditor";
import { getSupabaseAdmin, getSupabaseServer } from "@/lib/supabase";

export const dynamic = "force-dynamic";

export const metadata = { title: "Dashboard - ChorusFrame" };

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
  vertical: "9:16 vertical",
  square: "1:1 square",
  wide: "16:9 wide",
  canvas: "Canvas loop",
  sample: "Clip",
};

/** "abc123-vertical.mp4" or legacy "sample-vertical.mp4" -> "vertical". */
const formatOfName = (name: string) =>
  name.replace(/\.mp4$/, "").split("-").pop() ?? "clip";

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
  // Every finished render, newest first — the clip library. Files are keyed
  // per render in storage, so nothing here ever overwrites anything else.
  const doneJobs = new Map<string, (RenderJob & { submission_id: string })[]>();
  for (const j of (jobRows ?? []) as (RenderJob & { submission_id: string })[]) {
    if (!latestJob.has(j.submission_id)) latestJob.set(j.submission_id, j);
    if (j.status === "done" && j.clip_urls?.length) {
      const list = doneJobs.get(j.submission_id) ?? [];
      list.push(j);
      doneJobs.set(j.submission_id, list);
    }
  }

  /*
   * Beat grids sit behind a migration that may not have been run yet, so this
   * is a separate query that is allowed to fail. Selecting these columns in the
   * main query took the entire dashboard down with "column submissions.bpm does
   * not exist" — a missing optional feature must never cost an artist the page.
   */
  const beatGrids = new Map<string, { bpm: number; offset: number }>();
  const savedTimings = new Map<string, TimedLine[]>();
  const timingSources = new Map<string, string>();
  {
    const { data: grids } = await supabase
      .from("submissions")
      .select("id, bpm, beat_offset, lyrics_timing, timing_source");
    for (const g of (grids ?? []) as {
      id: string;
      bpm: number | null;
      beat_offset: number | null;
      lyrics_timing: TimedLine[] | null;
      timing_source: string | null;
    }[]) {
      if (g.timing_source) timingSources.set(g.id, g.timing_source);
      if (Array.isArray(g.lyrics_timing) && g.lyrics_timing.length) {
        savedTimings.set(g.id, g.lyrics_timing);
      }
      if (g.bpm != null && g.beat_offset != null) {
        beatGrids.set(g.id, { bpm: Number(g.bpm), offset: Number(g.beat_offset) });
      }
    }
  }

  // Counted in SQL rather than here, so the rule that failed renders don't
  // count is defined once. A missing function (unrun migration) reads as zero
  // rather than taking the page down.
  let exportsUsed = 0;
  {
    const { data: used } = await supabase.rpc("exports_used_this_month", {
      p_user: user?.id ?? "",
    });
    if (typeof used === "number") exportsUsed = used;
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

  // The name they release under — from their newest song, their signup
  // metadata, or the front of their email, in that order.
  const displayName =
    submissions.find((x) => x.artist_name)?.artist_name ??
    (user?.user_metadata?.artist_name as string | undefined) ??
    (user?.email ?? "artist").split("@")[0];

  const admin = getSupabaseAdmin();

  // Claim mechanic: anonymous uploads made with this (now verified) email
  // become theirs. The upload page promises exactly this, and sign-in is what
  // proves the address, so this is the safe moment to adopt.
  if (admin && user?.email) {
    await admin
      .from("submissions")
      .update({ user_id: user.id })
      .eq("email", user.email.toLowerCase())
      .is("user_id", null);
  }

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
        // Legacy only: songs rendered before the job table carried clip_urls.
        if (!doneJobs.has(s.id)) {
          const { data: files } = await admin.storage.from("clips").list(s.id);
          if (files?.length) {
            clipFiles.set(
              s.id,
              files
                // Legacy stable names only: job-keyed files belong to the job
                // table, and a failed job's partial uploads must not surface
                .filter((f) => f.name.endsWith(".mp4") && f.name.startsWith("sample"))
                .map((f) => ({
                  name: f.name,
                  // Clips cache at the edge for a year; the URL must change
                  // when the file does.
                  url: `${admin.storage.from("clips").getPublicUrl(`${s.id}/${f.name}`).data.publicUrl}?v=${encodeURIComponent(
                    f.updated_at ?? f.created_at ?? ""
                  )}`,
                }))
            );
          }
        }
      })
    );
  }

  /**
   * The song's current clips: the newest finished render of EACH format —
   * a quick vertical-only re-render must not make the square and wide
   * disappear from the page — or legacy files for pre-queue songs.
   */
  const currentClips = (id: string): { format: string; url: string }[] => {
    const jobs = doneJobs.get(id);
    if (jobs?.length) {
      const byFormat = new Map<string, { format: string; url: string }>();
      for (const j of jobs) {
        for (const c of j.clip_urls ?? []) {
          if (!byFormat.has(c.format)) byFormat.set(c.format, c);
        }
      }
      return [...byFormat.values()];
    }
    return (clipFiles.get(id) ?? []).map((f) => ({ format: formatOfName(f.name), url: f.url }));
  };

  // One vertical per song, newest song first — the dashboard's shop window
  const freshClips = submissions
    .map((x) => {
      const v = currentClips(x.id).find((c) => c.format === "vertical");
      return v ? { song: x.song_title, url: v.url } : null;
    })
    .filter((x): x is { song: string; url: string } => x !== null)
    .slice(0, 4);

  return (
    <>
    <SiteHeader>
      <div className="flex items-center gap-4 text-sm">
        <Link href="/upload" className="text-muted transition hover:text-foreground">
          New upload
        </Link>
        <form action="/auth/signout" method="post">
          <button type="submit" className="rounded-lg text-muted transition hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan">
            Sign out
          </button>
        </form>
      </div>
    </SiteHeader>
    <main className="mx-auto w-full max-w-5xl flex-1 px-6">

      <section className="py-8">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">
              Welcome back, <span className="brand-text">{displayName}</span>
            </h1>
            <p className="mt-1 text-sm text-muted">
              Here&apos;s where your releases stand.
            </p>
          </div>
          <Link
            href="/upload"
            className="glow-hover-strong brand-gradient rounded-full px-5 py-2.5 text-sm font-semibold text-white transition hover:opacity-90"
          >
            Upload a song
          </Link>
        </div>
        <div className="mt-2 flex flex-wrap items-baseline gap-x-3 gap-y-1">
          <p className="text-sm text-muted">Signed in as {user?.email}</p>
          <SetPassword
            hasPassword={Boolean(
              (user?.identities ?? []).some((i) => i.provider === "email") &&
                user?.user_metadata?.has_password
            )}
          />
        </div>

        {/* A kit belongs to the artist, not to a song, so it lives up here.
            It's a Pro feature: Free sees what it is and where to get it,
            not a form that saves settings no render will use. */}
        <div className="mt-4">
          {plan.brandKit ? (
            <BrandKit
              initial={{
                primary: profile?.brand_primary ?? null,
                secondary: profile?.brand_secondary ?? null,
                font: profile?.brand_font ?? null,
              }}
            />
          ) : (
            <Link
              href="/dashboard/billing"
              className="glow-hover flex w-fit items-center gap-2 rounded-lg border border-borderline px-3 py-1.5 text-xs text-muted transition hover:border-cyan hover:text-foreground"
            >
              <span
                aria-hidden
                className="h-3 w-3 rounded-full"
                style={{ background: "linear-gradient(135deg, #22dcf5, #7c3aed)" }}
              />
              Brand kit — your colours on every render, on Pro
            </Link>
          )}
        </div>

        {submissions.length > 0 ? (
          <div className="mt-6">
            <LibraryStats
              plan={plan}
              exportsUsed={exportsUsed}
              songs={submissions.length}
              clips={submissions.reduce((n, x) => n + currentClips(x.id).length, 0)}
            />
          </div>
        ) : null}

        {freshClips.length > 0 ? (
          <section className="mt-6">
            <div className="flex items-baseline justify-between">
              <h2 className="text-lg font-semibold">Fresh clips</h2>
              <p className="text-xs text-muted">Newest first — tap to play</p>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-4 sm:grid-cols-4">
              {freshClips.map((c) => (
                <figure key={c.url}>
                  <video
                    src={c.url}
                    controls
                    playsInline
                    preload="metadata"
                    className="w-full rounded-xl border border-borderline bg-surface"
                    style={{ aspectRatio: "9 / 16" }}
                  />
                  <figcaption className="mt-1.5 flex items-baseline justify-between gap-2 text-xs">
                    <span className="truncate">{c.song}</span>
                    <a href={c.url} download className="shrink-0 text-cyan underline underline-offset-4">
                      Download
                    </a>
                  </figcaption>
                </figure>
              ))}
            </div>
          </section>
        ) : null}

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
              Upload a song, pick the hook, and render every format yourself —
              your first clip is minutes away.
            </p>
            <Link
              href="/upload"
              className="glow-hover-strong brand-gradient mt-6 inline-block rounded-full px-6 py-3 text-sm font-semibold text-white transition hover:opacity-90"
            >
              Upload a song
            </Link>
          </div>
        ) : (
          <>
          <h2 className="mt-8 text-lg font-semibold">
            Your songs <span className="text-sm font-normal text-muted">({submissions.length})</span>
          </h2>
          <ul className="mt-3 flex flex-col gap-4">
            {submissions.map((s) => {
              const badge = STATUS[s.status] ?? {
                label: s.status,
                cls: "border-borderline text-muted",
              };
              const clips = currentClips(s.id);
              // Pre-deploy jobs all alias the same overwritten sample-* files;
              // listing them as "earlier renders" would show duplicates at
              // best and year-old edge-cached bytes at worst.
              const earlier = (doneJobs.get(s.id) ?? [])
                .slice(1)
                .filter((j) => !(j.clip_urls ?? []).some((c) => c.url.includes("/sample-")));
              const thumb = artThumbs.get(s.id);
              const totalClipCount =
                (doneJobs.get(s.id) ?? []).reduce((n, j) => n + (j.clip_urls?.length ?? 0), 0) ||
                clips.length;
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
                    <SongMeta
                      hasLyrics={Boolean((s.lyrics ?? "").trim())}
                      timingSource={timingSources.get(s.id) ?? null}
                      bpm={beatGrids.get(s.id)?.bpm ?? null}
                      clipCount={clips.length}
                    />

                    {clips.length > 0 ? (
                      <div className="mt-2 flex flex-wrap items-center gap-2">
                        <ShareLink submissionId={s.id} />
                        {clips.map((c) => (
                          <a
                            key={c.url}
                            href={c.url}
                            target="_blank"
                            rel="noreferrer"
                            className="glow-hover rounded-lg bg-surface-raised px-2.5 py-1 text-xs text-muted transition hover:text-foreground"
                          >
                            {FORMAT_LABELS[c.format] ?? c.format} ↗
                          </a>
                        ))}
                      </div>
                    ) : null}
                    {earlier.length > 0 ? (
                      <details className="mt-2">
                        <summary className="cursor-pointer text-xs text-muted transition hover:text-foreground">
                          Earlier renders ({earlier.length})
                        </summary>
                        <ul className="mt-1.5 flex flex-col gap-1.5">
                          {earlier.map((j) => (
                            <li key={j.id} className="flex flex-wrap items-center gap-2 text-xs text-muted">
                              {(j.clip_urls ?? []).map((c) => (
                                <a
                                  key={c.url}
                                  href={c.url}
                                  target="_blank"
                                  rel="noreferrer"
                                  className="rounded bg-surface-raised px-2 py-0.5 transition hover:text-foreground"
                                >
                                  {FORMAT_LABELS[c.format] ?? c.format} ↗
                                </a>
                              ))}
                            </li>
                          ))}
                        </ul>
                      </details>
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
                        allowedVibes={plan.templateIds}
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
                      clipCount={totalClipCount}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
          </>
        )}
      </section>
    </main>
    </>
  );
}
