import Link from "next/link";
import Logo from "@/components/Logo";

/**
 * One footer for every marketing page — same links, same hover states, same
 * shape, so moving between pages doesn't reshuffle the ground floor.
 */
export default function SiteFooter() {
  return (
    <footer className="flex flex-col items-center gap-3 border-t border-borderline py-10 text-center text-xs text-muted">
      <Logo size={26} />
      <p>The video studio built for music releases. · © 2026 ChorusFrame</p>
      <nav className="flex flex-wrap justify-center gap-4">
        <Link href="/examples" className="transition hover:text-foreground">
          Examples
        </Link>
        <Link href="/pricing" className="transition hover:text-foreground">
          Pricing
        </Link>
        <Link href="/legal/terms" className="transition hover:text-foreground">
          Terms
        </Link>
        <Link href="/legal/privacy" className="transition hover:text-foreground">
          Privacy
        </Link>
        <Link href="/legal/copyright" className="transition hover:text-foreground">
          Copyright
        </Link>
      </nav>
      <p>By uploading, you confirm you own the rights to your music and artwork.</p>
    </footer>
  );
}
