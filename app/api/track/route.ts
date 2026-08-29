import { NextResponse } from "next/server";
import { getCurrentUser } from "@/lib/supabase";
import { track, type EventName } from "@/lib/track";

export const runtime = "nodejs";

/**
 * The only events a browser may send.
 *
 *   page_view    the server never sees a view of a static page
 *   arrived      "I just got a session" — the SERVER decides whether that is
 *                a signup, from the account it reads out of the cookie, so a
 *                caller cannot invent signups
 *
 * Everything else — uploads, renders, upgrades — is recorded where it
 * actually happens, server-side.
 */
const CLIENT_EVENTS = new Set(["page_view", "arrived"]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** A bare hostname — never a full referring URL. */
const HOST = /^[a-z0-9.-]{1,80}$/i;

/**
 * An artist's account is minutes old when the magic-link round trip lands, so
 * this window has to comfortably cover reading an email. Paired with a check
 * for an existing signup event, a generous window can't double-count.
 */
const SIGNUP_WINDOW_MS = 6 * 60 * 60 * 1000;

export async function POST(req: Request) {
  // Same-origin only. This is an unauthenticated write, and without this a
  // script anywhere could pour rows into the funnel (and the bill).
  const origin = req.headers.get("origin");
  if (origin) {
    try {
      if (new URL(origin).host !== new URL(req.url).host) {
        return NextResponse.json({ ok: true });
      }
    } catch {
      return NextResponse.json({ ok: true });
    }
  }

  const body = await req.json().catch(() => null);
  const name = String(body?.name ?? "");
  if (!CLIENT_EVENTS.has(name)) return NextResponse.json({ ok: true });

  const user = await getCurrentUser().catch(() => null);
  const anonId =
    typeof body.anonId === "string" && UUID.test(body.anonId) ? body.anonId : null;

  if (name === "arrived") {
    // Only the server may conclude a signup happened, and only once.
    if (!user) return NextResponse.json({ ok: true });
    await recordSignupOnce(user.id, user.created_at, anonId);
    return NextResponse.json({ ok: true });
  }

  const ref = typeof body.ref === "string" && HOST.test(body.ref) ? body.ref : "";
  await track("page_view", {
    userId: user?.id ?? null,
    anonId,
    path: typeof body.path === "string" ? body.path : null,
    props: ref ? { ref } : {},
  });

  return NextResponse.json({ ok: true });
}

/**
 * Record a signup for an account that has just arrived, if we haven't
 * already. The anon id rides along so a signup can be traced back to the
 * visit that produced it — the only way to answer where paying artists
 * actually come from.
 */
export async function recordSignupOnce(
  userId: string,
  createdAt: string | undefined,
  anonId: string | null
) {
  const created = Date.parse(createdAt ?? "");
  if (!Number.isFinite(created) || Date.now() - created > SIGNUP_WINDOW_MS) return;

  const { getSupabaseAdmin } = await import("@/lib/supabase");
  const admin = getSupabaseAdmin();
  if (!admin) return;

  const { data: existing } = await admin
    .from("events")
    .select("id")
    .eq("name", "signup")
    .eq("user_id", userId)
    .limit(1);
  if (existing?.length) return;

  await track("signup", { userId, anonId, path: "/auth/callback" });
}
