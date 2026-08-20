import Stripe from "stripe";

/**
 * Stripe, or null when checkout isn't switched on.
 *
 * Same pattern as transcription and email: the whole path is real code that
 * activates the moment STRIPE_SECRET_KEY exists, and until then callers say
 * so honestly instead of showing a dead button.
 */
export function getStripe(): Stripe | null {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) return null;
  return new Stripe(key);
}

export const SITE_URL =
  process.env.NEXT_PUBLIC_SITE_URL || "https://verseframe.vercel.app";
