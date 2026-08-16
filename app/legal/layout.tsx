import Link from "next/link";
import Logo from "@/components/Logo";

export default function LegalLayout({ children }: LayoutProps<"/legal">) {
  return (
    <main className="mx-auto w-full max-w-2xl flex-1 px-6">
      <header className="py-6">
        <Link
          href="/"
          className="inline-flex items-center gap-2 rounded-lg text-muted transition hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan"
        >
          <span aria-hidden>←</span>
          <Logo size={26} />
        </Link>
      </header>

      <article
        className="pb-20 pt-4 [&_a]:text-cyan [&_a]:underline [&_a]:underline-offset-4 [&_h1]:mb-2 [&_h1]:text-3xl [&_h1]:font-bold [&_h1]:tracking-tight [&_h2]:mt-10 [&_h2]:mb-3 [&_h2]:text-lg [&_h2]:font-semibold [&_li]:mb-1.5 [&_p]:mb-4 [&_p]:leading-relaxed [&_p]:text-muted [&_ul]:mb-4 [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:text-muted"
      >
        {children}
      </article>

      <footer className="flex flex-wrap justify-center gap-4 border-t border-borderline py-8 text-center text-xs text-muted">
        <Link href="/legal/terms">Terms</Link>
        <Link href="/legal/privacy">Privacy</Link>
        <Link href="/legal/copyright">Copyright</Link>
      </footer>
    </main>
  );
}
