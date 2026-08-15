import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "@/lib/supabase";

export async function POST(req: Request) {
  let body: { email?: string; artistName?: string; genre?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }

  const email = body.email?.trim().toLowerCase();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ error: "Enter a valid email" }, { status: 400 });
  }

  const supabase = getSupabaseAdmin();
  if (!supabase) {
    console.warn("[waitlist] Supabase not configured — demo mode, not persisted:", email);
    return NextResponse.json({ ok: true, demo: true });
  }

  const { error } = await supabase.from("waitlist").insert({
    email,
    artist_name: body.artistName?.trim() || null,
    genre: body.genre?.trim() || null,
  });

  if (error) {
    // 23505 = unique_violation: already on the list, treat as success
    if (error.code === "23505") return NextResponse.json({ ok: true });
    console.error("[waitlist] insert failed:", error);
    return NextResponse.json({ error: "Something went wrong. Try again." }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
