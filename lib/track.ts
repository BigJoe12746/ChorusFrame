import { getSupabaseAdmin } from "@/lib/supabase";

/**
 * Record a product event.
 *
 * Two rules make this safe to call from anywhere:
 *
 *   1. It never throws and never fails the caller's work. Analytics that can
 *      fail an upload or a render is worse than no analytics — the point is
 *      to observe the product, not to become part of it. Failures are logged
 *      rather than swallowed silently, so a missing migration is visible.
 *   2. It records what happened, not who someone is. A user id when we have
 *      one, a random per-browser id when we don't, a route pattern, and a
 *      payload of values we chose deliberately. No IP, no user-agent, no
 *      fingerprint.
 *
 * Events are defined in supabase/010_events.sql and read through
 * funnel_metrics().
 */
export type EventName =
  | "page_view"
  | "signup"
  | "upload_complete"
  | "render_started"
  | "render_done"
  | "render_failed"
  | "checkout_started"
  | "upgrade_completed"
  | "subscription_canceled";

/**
 * Reduce a URL path to its route pattern: /c/2f9a-… becomes /c/[id].
 *
 * A resolved path would tie a persistent browser id to the specific artists
 * whose pages someone looked at — a browsing history in all but name, and
 * more than the funnel needs. The pattern answers "did share pages get
 * viewed" without answering "whose".
 */
export function routePattern(path: string | null | undefined): string | null {
  if (!path) return null;
  const clean = String(path).split("?")[0].split("#")[0].slice(0, 200);
  return clean
    .replace(
      /\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi,
      "/[id]"
    )
    // Any other long opaque segment is an id too
    .replace(/\/[A-Za-z0-9_-]{16,}\b/g, "/[id]");
}

export async function track(
  name: EventName,
  opts: {
    userId?: string | null;
    anonId?: string | null;
    path?: string | null;
    props?: Record<string, unknown>;
  } = {}
): Promise<void> {
  try {
    const supabase = getSupabaseAdmin();
    if (!supabase) return; // demo mode — nothing to record into

    const { error } = await supabase.from("events").insert({
      name,
      user_id: opts.userId ?? null,
      anon_id: opts.anonId ? String(opts.anonId).slice(0, 64) : null,
      path: routePattern(opts.path),
      props: opts.props ?? {},
    });
    // supabase-js resolves with an error rather than throwing, so the catch
    // below would never see a missing table or a permission problem.
    if (error && error.code !== "23505") {
      // 23505 is the upgrade-once unique index doing its job on a webhook retry
      console.warn(`[track] ${name} not recorded: ${error.message}`);
    }
  } catch (e) {
    console.warn("[track] skipped:", e instanceof Error ? e.message : e);
  }
}
