/**
 * Resolve a `next=` redirect target to a same-origin path.
 *
 * Pattern-matching the raw string is not enough: the WHATWG URL parser folds
 * backslashes into slashes and strips tab/CR/LF before parsing, so "/\evil.com"
 * and "/<TAB>/evil.com" both escape the origin while passing a naive
 * startsWith("/") check. Resolving first and comparing origins closes all of
 * those uniformly, because it runs the same normalization the redirect will.
 */
export function resolveNext(raw: string | null | undefined, origin: string): string {
  if (!raw) return "/dashboard";
  try {
    const target = new URL(raw, origin);
    if (target.origin !== origin) return "/dashboard";
    // Collapse leading slashes: "/..//evil.com" resolves same-origin here, but
    // its pathname is "//evil.com", which turns protocol-relative again the
    // next time it is parsed against an origin.
    const path = target.pathname.replace(/^\/+/, "/");
    return path + target.search + target.hash;
  } catch {
    return "/dashboard";
  }
}
