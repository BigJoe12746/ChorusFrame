import { NextResponse } from "next/server";
import type Stripe from "stripe";
import { getStripe } from "@/lib/stripe";
import { getSupabaseAdmin } from "@/lib/supabase";
import { track } from "@/lib/track";

export const runtime = "nodejs";

/**
 * Stripe tells us what happened; this is the only place the plan changes.
 *
 * The signature check is not optional ceremony: this endpoint is public, and
 * without verification anyone could POST a forged "subscription created" and
 * grant themselves Pro. No secret configured means no processing.
 */
export async function POST(req: Request) {
  const stripe = getStripe();
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!stripe || !secret) {
    return NextResponse.json({ error: "Billing isn't configured" }, { status: 503 });
  }

  const signature = req.headers.get("stripe-signature");
  if (!signature) return NextResponse.json({ error: "No signature" }, { status: 400 });

  let event: Stripe.Event;
  try {
    // Raw body, not parsed JSON — the signature covers the exact bytes
    event = await stripe.webhooks.constructEventAsync(await req.text(), signature, secret);
  } catch {
    return NextResponse.json({ error: "Bad signature" }, { status: 400 });
  }

  const supabase = getSupabaseAdmin();
  if (!supabase) return NextResponse.json({ error: "Not configured" }, { status: 503 });

  async function applySubscription(sub: Stripe.Subscription) {
    const userId = sub.metadata?.user_id;
    if (!userId) return; // not one of ours

    const status = sub.status;
    const active = status === "active" || status === "trialing";
    const periodEnd = sub.items.data[0]?.current_period_end;

    await supabase!
      .from("profiles")
      .update({
        plan: active ? "pro" : "free",
        plan_status: active ? "active" : status === "past_due" ? "past_due" : "canceled",
        plan_period_end: periodEnd ? new Date(periodEnd * 1000).toISOString() : null,
        stripe_subscription_id: sub.id,
        founding_member: sub.metadata?.founding === "1",
      })
      .eq("id", userId);
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object;
      if (session.mode === "subscription" && session.subscription) {
        const sub = await stripe.subscriptions.retrieve(String(session.subscription));
        await applySubscription(sub);
        await track("upgrade_completed", {
          userId: sub.metadata?.user_id ?? null,
          path: "/dashboard/billing",
          props: {
            // The unique index in 010_events.sql keys on this: Stripe
            // redelivering a webhook must not invent a second conversion.
            subscriptionId: sub.id,
            founding: sub.metadata?.founding === "1",
            interval: sub.items.data[0]?.price?.recurring?.interval ?? "unknown",
            amountCents: sub.items.data[0]?.price?.unit_amount ?? null,
          },
        });
      }
      break;
    }
    case "customer.subscription.updated":
      await applySubscription(event.data.object);
      break;
    case "customer.subscription.deleted": {
      const userId = event.data.object.metadata?.user_id;
      if (userId) {
        await supabase
          .from("profiles")
          .update({ plan: "free", plan_status: "canceled", stripe_subscription_id: null })
          .eq("id", userId);
        // Churn is unanswerable without this; nothing else records an ending.
        await track("subscription_canceled", {
          userId,
          path: "/dashboard/billing",
          props: { subscriptionId: event.data.object.id },
        });
      }
      break;
    }
    default:
      break; // acknowledged, deliberately ignored
  }

  return NextResponse.json({ received: true });
}
