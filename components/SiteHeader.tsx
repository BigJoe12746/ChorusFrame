import Link from "next/link";
import Logo from "@/components/Logo";
import NavAuth from "@/components/NavAuth";

/**
 * The site's navigation bar: sticky, frosted, hairline-separated — content
 * scrolls underneath it. One component so every page carries the identical
 * bar; the right-hand side defaults to the marketing nav and app pages pass
 * their own controls.
 */
export default function SiteHeader({ children }: { children?: React.ReactNode }) {
  return (
    <div className="glass sticky top-0 z-40 border-b border-borderline backdrop-blur-xl backdrop-saturate-150">
      <header className="mx-auto flex w-full max-w-5xl items-center justify-between px-6 py-4">
        <Link
          href="/"
          className="rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-cyan"
        >
          <Logo />
        </Link>
        {children ?? <NavAuth />}
      </header>
    </div>
  );
}
