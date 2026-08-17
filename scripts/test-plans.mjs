// Entitlement rules, checked against the business plan's pricing.
//   npm run test:plans
//
// The prices are asserted literally because a typo here is a wrong number on a
// public pricing page, and the "failed renders are free" rule is asserted
// because it is a promise the marketing page makes.

import { checkEntitlement, PLANS, money, FOUNDING, getPlan } from "../lib/plans.ts";

let fail = 0;
const ok = (n, c, d = "") => {
  if (!c) fail++;
  console.log(`  ${c ? "ok   " : "FAIL "} ${n}${!c && d ? ` — ${d}` : ""}`);
};

console.log("prices match the business plan:");
ok("Creator $9.99/mo", money(PLANS.creator.monthly) === "$9.99");
ok("Creator $79.99/yr", money(PLANS.creator.annual) === "$79.99");
ok("Creator AI $16.99/mo", money(PLANS.creator_ai.monthly) === "$16.99");
ok("Creator AI $139.99/yr", money(PLANS.creator_ai.annual) === "$139.99");
ok("Teams $19.99/mo", money(PLANS.teams.monthly) === "$19.99");
// Quoted as a monthly-equivalent when billed annually
ok(
  "Teams annual works out at $14.99/seat/mo",
  money(Math.round(PLANS.teams.annual / 12)) === "$14.99",
  money(Math.round(PLANS.teams.annual / 12))
);
ok("Founding year $59.99", money(FOUNDING.priceCents) === "$59.99");
ok("Founding capped at 1,000", FOUNDING.seats === 1000);
ok("Free is 10 exports a month", PLANS.free.exportsPerMonth === 10);
ok("annual beats monthly on every paid plan",
  ["creator", "creator_ai", "teams"].every((id) => PLANS[id].annual < PLANS[id].monthly * 12));

const base = { clipSeconds: 15, formats: ["vertical"] };
console.log("\nfree plan:");
ok("allows the first export", checkEntitlement({ planId: "free", usedThisMonth: 0, ...base }).allowed);
ok("allows the tenth", checkEntitlement({ planId: "free", usedThisMonth: 9, ...base }).allowed);
ok("refuses the eleventh", !checkEntitlement({ planId: "free", usedThisMonth: 10, ...base }).allowed);
const spent = checkEntitlement({ planId: "free", usedThisMonth: 10, ...base });
ok("keeps the failed-renders promise in the wording",
  /failed don't count/i.test(spent.reason ?? ""), spent.reason);
const tooLong = checkEntitlement({ planId: "free", usedThisMonth: 0, clipSeconds: 60, formats: ["vertical"] });
ok("refuses a 60s clip", !tooLong.allowed);
ok("says why, and what fixes it", /60 seconds|upgrade/i.test(tooLong.reason ?? ""), tooLong.reason);

console.log("\npaid plans:");
ok("Creator allows 60s", checkEntitlement({ planId: "creator", usedThisMonth: 0, clipSeconds: 60, formats: ["vertical"] }).allowed);
ok("Creator allows 100 a month", checkEntitlement({ planId: "creator", usedThisMonth: 99, ...base }).allowed);
ok("Creator stops after 100", !checkEntitlement({ planId: "creator", usedThisMonth: 100, ...base }).allowed);
ok("every plan includes all three formats",
  Object.values(PLANS).every((p) => ["vertical", "square", "wide"].every((f) => p.formats.includes(f))));

console.log("\nunknown plan must fall back to free, never to unlimited:");
ok("null", !checkEntitlement({ planId: null, usedThisMonth: 10, ...base }).allowed);
ok("undefined", !checkEntitlement({ planId: undefined, usedThisMonth: 10, ...base }).allowed);
ok("made-up id", !checkEntitlement({ planId: "enterprise_ultra", usedThisMonth: 10, ...base }).allowed);
ok("getPlan falls back to free", getPlan("nonsense").id === "free");
ok("remaining is never negative", checkEntitlement({ planId: "free", usedThisMonth: 999, ...base }).remaining === 0);

console.log(fail === 0 ? "\nPASS — entitlements match the plan" : `\nFAIL — ${fail} problem(s)`);
process.exit(fail ? 1 : 0);
