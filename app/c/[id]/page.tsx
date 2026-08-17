import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import Logo from "@/components/Logo";
import { getSupabaseAdmin } from "@/lib/supabase";

export const dynamic = "force-dynamic";

const FORMATS: Record<string, { label: string; where: string; ratio: string }> = {
  "sample-vertical.mp4": { label: "9:16 vertical", where: "TikTok, Reels, Shorts", ratio: "9 / 16" },
  "sample-square.mp4": { label: "1:1 square", where: "Feed posts", ratio: "1 / 1" },
  "sample-wide.mp4": { label: "16:9 wide", where: "YouTube", ratio: "16 / 9" },
  "sample.mp4": { label: "Clip", where: "", ratio: "9 / 16" },
};

/** Only what a public page should know — never the email or the master audio. */
async function loadClips(id: string) {
  const admin = getSupabaseAdmin();
  if (!admin) return null;

  const { data: sub } = await admin
    .from("submissions")
    .select("id, song_title, artist_name, artwork_path")
    .eq("id", id)
    .maybeSingle();
  if (!sub) return null;

  const { data: files } = await admin.storage.from("clips").list(id);
  const clips = (files ?? [])
    .filter((f) => f.name.endsWith(".mp4"))
    .map((f) => ({
      name: f.name,
      url: admin.storage.from("clips").getPublicUrl(`${id}/${f.name}`).data.publicUrl,
    }));
  if (!clips.length) return null;

  let artwork: string | null = null;
  if (sub.artwork_path) {
    const { data: signed } = await admin.storage
      .from("submissions")
      .createSignedUrl(sub.artwork_path, 3600);
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
    },
  };
}

export default async function ClipPage({ params }: PageProps<"/c/[id]">) {
  const data = await loadClips((await params).id);
  // A song with no finished clips has nothing to share, and saying so beats
  // a page that looks broken.
  if (!data) notFound();

  const { sub, clips, artwork } = data;
  const ordered = clips.sort(
    (a, b) => Object.keys(FORMATS).indexOf(a.name) - Object.keys(FORMATS).indexOf(b.name)
  );

  return (
    <main className="mx-auto w-full max-w-4xl flex-1 px-6">
      <header className="flex items-center justify-between py-6">
        <Link href="/">
          <Logo size={26} />
        </Link>
        <Link
          href="/login"
          className="rounded-lg border border-borderline px-4 py-2 text-sm text-muted transition hover:border-cyan hover:text-foreground"
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
          const meta = FORMATS[c.name] ?? { label: c.name, where: "", ratio: "9 / 16" };
          return (
            <figure key={c.name} className="flex flex-col gap-2">
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
                  className="text-cyan underline underline-offset-4"
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
        <nav className="flex gap-4">
          <Link href="/legal/terms">Terms</Link>
          <Link href="/legal/privacy">Privacy</Link>
          <Link href="/legal/copyright">Copyright</Link>
        </nav>
      </footer>
    </main>
  );
}
