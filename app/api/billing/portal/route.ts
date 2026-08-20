import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";
import { getStripe, SITE_URL } from "@/lib/stripe";

export const runtime = "nodejs";

/**
 * Stripe's billing portal: update card, switch monthly/annual, cancel.
 * Cancel living HERE is what makes "cancel whenever" on the pricing page a
 * self-serve truth rather than a support ticket.
 */
export async function POST() {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Sign in first" }, { status: 401 });

  const stripe = getStripe();
  if (!stripe) {
    return NextResponse.json({ error: "Billing isn't live yet" }, { status: 503 });
  }

  const supabase = getSupabaseAdmin();
  if (!supabase) return NextResponse.json({ error: "Not configured" }, { status: 503 });

  const { data: profile } = await supabase
    .from("profiles")
    .select("stripe_customer_id")
    .eq("id", user.id)
    .maybeSingle();

  if (!profile?.stripe_customer_id) {
    return NextResponse.json({ error: "No billing history yet" }, { status: 404 });
  }

  const session = await stripe.billingPortal.sessions.create({
    customer: profile.stripe_customer_id,
    return_url: `${SITE_URL}/dashboard/billing`,
  });

  return NextResponse.json({ url: session.url });
}
