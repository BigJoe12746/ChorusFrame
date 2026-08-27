import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import Logo from "@/components/Logo";
import { getSupabaseAdmin } from "@/lib/supabase";
import { LEGAL_CONTACT } from "@/app/legal/contact";

export const dynamic = "force-dynamic";

const FORMATS: Record<string, { label: string; where: string; ratio: string }> = {
  vertical: { label: "9:16 vertical", where: "TikTok, Reels, Shorts", ratio: "9 / 16" },
  square: { label: "1:1 square", where: "Feed posts", ratio: "1 / 1" },
  wide: { label: "16:9 wide", where: "YouTube", ratio: "16 / 9" },
  sample: { label: "Clip", where: "", ratio: "9 / 16" },
};

/** "abc123-vertical.mp4" or legacy "sample-vertical.mp4" -> "vertical". */
const formatOfName = (name: string) =>
  name.replace(/\.mp4$/, "").split("-").pop() ?? "clip";

/** Only what a public page should know — never the email or the master audio. */
async function loadClips(id: string) {
  const admin = getSupabaseAdmin();
  if (!admin) return null;

  // removed_at is the takedown switch from migration 009; tolerate the
  // column not existing yet so the page keeps working pre-migration.
  let sub:
    | { id: string; song_title: string; artist_name: string | null; artwork_path: string | null; removed_at?: string | null }
    | null = null;
  {
    const withFlag = await admin
      .from("submissions")
      .select("id, song_title, artist_name, artwork_path, removed_at")
      .eq("id", id)
      .maybeSingle();
    if (withFlag.error && /removed_at/.test(withFlag.error.message)) {
      const legacy = await admin
        .from("submissions")
        .select("id, song_title, artist_name, artwork_path")
        .eq("id", id)
        .maybeSingle();
      sub = legacy.data;
    } else {
      sub = withFlag.data;
    }
  }
  if (!sub || sub.removed_at) return null;

  // The newest finished render of EACH format. Merging across renders means
  // a quick vertical-only re-render can't shrink a page an artist already
  // shared — followers keep seeing the square and wide from the last full run.
  let clips: { format: string; url: string }[] = [];
  const { data: doneJobs } = await admin
    .from("render_jobs")
    .select("clip_urls")
    .eq("submission_id", id)
    .eq("status", "done")
    .order("finished_at", { ascending: false })
    .limit(10);
  const byFormat = new Map<string, { format: string; url: string }>();
  for (const j of doneJobs ?? []) {
    for (const c of (j.clip_urls ?? []) as { format: string; url: string }[]) {
      if (!byFormat.has(c.format)) byFormat.set(c.format, c);
    }
  }
  clips = [...byFormat.values()];
  if (!clips.length) {
    // Legacy songs rendered before jobs carried clip_urls. Stable names only:
    // a failed job's partial uploads must not surface here.
    const { data: files } = await admin.storage.from("clips").list(id);
    clips = (files ?? [])
      .filter((f) => f.name.endsWith(".mp4") && f.name.startsWith("sample"))
      .map((f) => ({
        format: formatOfName(f.name),
        // Year-long CDN lifetime: the URL must change when the file does.
        url: `${admin.storage.from("clips").getPublicUrl(`${id}/${f.name}`).data.publicUrl}?v=${encodeURIComponent(
          f.updated_at ?? f.created_at ?? ""
        )}`,
      }));
  }
  if (!clips.length) return null;

  let artwork: string | null = null;
  if (sub.artwork_path) {
    const { data: signed } = await admin.storage
      .from("submissions")
      .createSignedUrl(sub.artwork_path, 60 * 60 * 24 * 7);
    artwork = signed?.signedUrl ?? null;
  }
  return { sub, clips, artwork };
}

export async function generateMetadata({
  params,
}: PageProps<"/c/[id]">): Promise<Metadata> {
  const data = await loadClips((await params).id);
  if (!data) return { title: "Clip not found — ChorusFrame" };
  const who = data.sub.artist_name ? ` by ${data.sub.artist_name}` : "";
  return {
    title: `${data.sub.song_title}${who} — ChorusFrame`,
    description: `Release clips for ${data.sub.song_title}${who}.`,
    openGraph: {
      title: `${data.sub.song_title}${who}`,
      description: "Release clips, ready to post.",
      videos: data.clips.map((c) => c.url),
      images: data.artwork ? [data.artwork] : undefined,
    },
  };
}

export default async function ClipPage({ params }: PageProps<"/c/[id]">) {
  const data = await loadClips((await params).id);
  // A song with no finished clips has nothing to share, and saying so beats
  // a page that looks broken.
  if (!data) notFound();

  const { sub, clips, artwork } = data;
  const order = Object.keys(FORMATS);
  const ordered = [...clips].sort(
    (a, b) => order.indexOf(a.format) - order.indexOf(b.format)
  );

  return (
    <main className="mx-auto w-full max-w-4xl flex-1 px-6">
      <header className="flex items-center justify-between py-6">
        <Link href="/" className="inline-flex rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan">
          <Logo size={26} />
        </Link>
        <Link
          href="/upload?from=share"
          className="glow-hover rounded-lg border border-borderline px-4 py-2 text-sm text-muted transition hover:border-cyan hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-cyan"
        >
          Make your own
        </Link>
      </header>

      <section className="flex flex-col items-center gap-4 py-8 text-center sm:flex-row sm:items-end sm:text-left">
        {artwork ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={artwork}
            alt=""
            className="h-24 w-24 rounded-xl object-cover"
          />
        ) : null}
        <div>
          {sub.artist_name ? (
            <p className="text-sm font-medium uppercase tracking-[0.2em] text-cyan">
              {sub.artist_name}
            </p>
          ) : null}
          <h1 className="mt-1 text-3xl font-bold tracking-tight sm:text-4xl">
            {sub.song_title}
          </h1>
          <p className="mt-2 text-sm text-muted">
            {ordered.length} clip{ordered.length === 1 ? "" : "s"}, ready to post
          </p>
        </div>
      </section>

      <section className="grid gap-6 pb-16 sm:grid-cols-2 lg:grid-cols-3">
        {ordered.map((c) => {
          const meta = FORMATS[c.format] ?? { label: c.format, where: "", ratio: "9 / 16" };
          return (
            <figure key={c.url} className="flex flex-col gap-2">
              <video
                src={c.url}
                controls
                playsInline
                preload="metadata"
                className="w-full rounded-xl border border-borderline bg-surface"
                style={{ aspectRatio: meta.ratio }}
              />
              <figcaption className="flex items-baseline justify-between text-xs">
                <span>
                  <span className="font-medium">{meta.label}</span>
                  {meta.where ? <span className="text-muted"> · {meta.where}</span> : null}
                </span>
                <a
                  href={c.url}
                  download
                  className="rounded text-cyan underline underline-offset-4 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan"
                >
                  Download
                </a>
              </figcaption>
            </figure>
          );
        })}
      </section>

      <footer className="flex flex-col items-center gap-3 border-t border-borderline py-8 text-center text-xs text-muted">
        <p>
          Made with{" "}
          <Link href="/" className="text-cyan underline underline-offset-4">
            ChorusFrame
          </Link>{" "}
          — upload a song, get your release clips.
        </p>
        <nav className="flex flex-wrap justify-center gap-4">
          <Link href="/legal/terms" className="transition hover:text-foreground">Terms</Link>
          <Link href="/legal/privacy" className="transition hover:text-foreground">Privacy</Link>
          <Link href="/legal/copyright" className="transition hover:text-foreground">Copyright</Link>
          <a
            href={`mailto:${LEGAL_CONTACT}?subject=Report%20clip%20${sub.id}`}
            className="transition hover:text-foreground"
          >
            Report this clip
          </a>
        </nav>
      </footer>
    </main>
  );
}
