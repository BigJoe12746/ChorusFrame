import { NextResponse } from "next/server";
import { getCurrentUser, getSupabaseAdmin } from "@/lib/supabase";
import { getStripe, SITE_URL } from "@/lib/stripe";
import { FOUNDING, PLANS } from "@/lib/plans";

export const runtime = "nodejs";

type Interval = "monthly" | "annual" | "founding";

/**
 * Start a Stripe Checkout for Pro.
 *
 * Prices come from lib/plans.ts — the same source of truth the pricing page
 * and the entitlement checks read — passed inline as price_data so there is
 * no Stripe dashboard product to drift out of sync.
 */
export async function POST(req: Request) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Sign in first" }, { status: 401 });

  const stripe = getStripe();
  if (!stripe) {
    return NextResponse.json(
      { error: "Checkout isn't live yet — Pro can't be bought until it is. Nothing was charged." },
      { status: 503 }
    );
  }

  const supabase = getSupabaseAdmin();
  if (!supabase) return NextResponse.json({ error: "Not configured" }, { status: 503 });

  const body = await req.json().catch(() => null);
  const interval = (body?.interval ?? "monthly") as Interval;
  if (!["monthly", "annual", "founding"].includes(interval)) {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }

  // The founding offer is finite by definition — check the count in SQL
  if (interval === "founding") {
    const { data: taken } = await supabase.rpc("founding_seats_taken");
    if (typeof taken === "number" && taken >= FOUNDING.seats) {
      return NextResponse.json(
        { error: "The founding-year seats are gone — standard Pro is still open." },
        { status: 409 }
      );
    }
  }

  // Reuse the Stripe customer across purchases so history stays in one place
  const { data: profile } = await supabase
    .from("profiles")
    .select("stripe_customer_id")
    .eq("id", user.id)
    .maybeSingle();

  let customerId = profile?.stripe_customer_id ?? null;
  if (!customerId) {
    const customer = await stripe.customers.create({
      email: user.email ?? undefined,
      metadata: { user_id: user.id },
    });
    customerId = customer.id;
    await supabase.from("profiles").update({ stripe_customer_id: customerId }).eq("id", user.id);
  }

  const pro = PLANS.pro;
  const price =
    interval === "monthly"
      ? { unit_amount: pro.monthly, recurring: { interval: "month" as const } }
      : interval === "annual"
        ? { unit_amount: pro.annual, recurring: { interval: "year" as const } }
        : // Founding: $59.99/yr, and it RENEWS at $59.99 — founding members
          // keep this price for as long as they stay subscribed. That promise
          // is in the Terms; do not add a renewal-time price bump.
          { unit_amount: FOUNDING.priceCents, recurring: { interval: "year" as const } };

  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: "subscription",
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency: "usd",
          product_data: {
            name:
              interval === "founding"
                ? "ChorusFrame Pro — Founding year"
                : "ChorusFrame Pro",
          },
          ...price,
        },
      },
    ],
    subscription_data: {
      metadata: { user_id: user.id, founding: interval === "founding" ? "1" : "0" },
    },
    metadata: { user_id: user.id, founding: interval === "founding" ? "1" : "0" },
    success_url: `${SITE_URL}/dashboard/billing?upgraded=1`,
    cancel_url: `${SITE_URL}/dashboard/billing`,
    allow_promotion_codes: true,
  });

  return NextResponse.json({ url: session.url });
}
