import Link from "next/link";
import { getCurrentUser, isAuthConfigured } from "@/lib/supabase";

/** Right-hand nav links, reflecting whether the artist is signed in. */
export default async function NavAuth() {
  const user = isAuthConfigured() ? await getCurrentUser() : null;

  return (
    <div className="flex items-center gap-3 text-sm">
      {user ? (
        <Link
          href="/dashboard"
          className="rounded-lg border border-borderline px-4 py-2 text-muted transition hover:border-cyan hover:text-foreground"
        >
          Your songs
        </Link>
      ) : (
        <>
          {isAuthConfigured() ? (
            <Link href="/login" className="px-2 py-2 text-muted transition hover:text-foreground">
              Sign in
            </Link>
          ) : null}
          <Link
            href="/upload"
            className="rounded-lg border border-borderline px-4 py-2 text-muted transition hover:border-cyan hover:text-foreground"
          >
            Get a free sample clip
          </Link>
        </>
      )}
    </div>
  );
}
