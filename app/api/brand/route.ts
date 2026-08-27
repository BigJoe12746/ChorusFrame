import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";

export const runtime = "nodejs";

const HEX = /^#[0-9a-f]{6}$/i;
const FONTS = ["sans", "serif", "mono"] as const;
const VIBES = [
  "hyperpop", "anime", "dreamy", "cinematic", "reggae",
  "minimal", "poster", "typographic", "retro", "neon",
];

/**
 * Save an artist's brand kit.
 *
 * Colours end up in inline style attributes on the rendered frames, so they're
 * validated as strict hex rather than passed through — a free-text colour is a
 * string that reaches CSS.
 */
export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Sign in first" }, { status: 401 });

  const supabase = getSupabaseAdmin();
  if (!supabase) return NextResponse.json({ error: "Not configured" }, { status: 503 });

  // The kit is a Pro feature — the render pipeline only applies it for Pro,
  // and letting Free save one that never renders would be a quiet lie.
  const { data: me } = await supabase
    .from("profiles")
    .select("plan")
    .eq("id", user.id)
    .maybeSingle();
  if (me?.plan !== "pro") {
    return NextResponse.json(
      { error: "The brand kit is a Pro feature.", upgrade: true },
      { status: 402 }
    );
  }

  const body = await req.json().catch(() => null);
  if (!body) return NextResponse.json({ error: "Invalid request" }, { status: 400 });

  const clean = (v: unknown, test: (s: string) => boolean) => {
    if (v === null || v === "") return null; // explicit clear
    const s = String(v);
    return test(s) ? s : undefined; // undefined = reject
  };

  const primary = clean(body.primary, (s) => HEX.test(s));
  const secondary = clean(body.secondary, (s) => HEX.test(s));
  const font = clean(body.font, (s) => FONTS.includes(s as (typeof FONTS)[number]));
  const vibe = clean(body.defaultVibe, (s) => VIBES.includes(s));

  if ([primary, secondary, font, vibe].includes(undefined as never)) {
    return NextResponse.json(
      { error: "Colours must be hex like #22dcf5, and font must be sans, serif or mono." },
      { status: 400 }
    );
  }

  const { error } = await supabase
    .from("profiles")
    .update({
      brand_primary: primary,
      brand_secondary: secondary,
      brand_font: font,
      default_vibe: vibe,
    })
    .eq("id", user.id);

  if (error) {
    console.error("[brand] update failed:", error);
    return NextResponse.json({ error: "Could not save your brand kit" }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
