import { NextResponse } from "next/server";
import { getSupabaseServer } from "@/lib/supabase";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const supabase = await getSupabaseServer();
  if (supabase) await supabase.auth.signOut();
  return NextResponse.redirect(new URL("/", new URL(request.url).origin), {
    status: 303, // turn the POST into a GET so the browser lands on the homepage
  });
}
