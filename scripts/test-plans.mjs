// Tests for plans and entitlements.  npm run test:plans
//
// These guard the two promises printed on the marketing page — that an artist
// always knows what an export costs, and that a failed render never costs one
// — plus the limits the API enforces.

import { PLANS, FOUNDING, checkEntitlement, getPlan, money } from "../lib/plans.ts";

let failures = 0;
const ok = (name, cond, detail = "") => {
  if (!cond) failures++;
  console.log(`  ${cond ? "ok   " : "FAIL "} ${name}${detail && !cond ? ` — ${detail}` : ""}`);
};

console.log("two plans, both real:");
ok("exactly Free and Pro", Object.keys(PLANS).join(",") === "free,pro", Object.keys(PLANS).join(","));
ok("Pro is $10/mo", money(PLANS.pro.monthly) === "$10", money(PLANS.pro.monthly));
ok("Pro annual is cheaper per month", PLANS.pro.annual / 12 < PLANS.pro.monthly);
ok("Free costs nothing", money(PLANS.free.monthly) === "Free");
ok("founding price beats the annual", FOUNDING.priceCents < PLANS.pro.annual);
ok("founding upgrades to Pro", FOUNDING.planId === "pro");

console.log("");
console.log("Free is limited but not crippled:");
ok("every format on Free", PLANS.free.formats.length === 3);
ok("shorter clips on Free", PLANS.free.maxClipSeconds < PLANS.pro.maxClipSeconds);
ok("fewer templates on Free", PLANS.free.templates < PLANS.pro.templates);
ok("end card only on Free", PLANS.free.endCard && !PLANS.pro.endCard);
ok("brand kit is a Pro feature", !PLANS.free.brandKit && PLANS.pro.brandKit);

console.log("");
console.log("entitlement decisions:");
const free = (over) => checkEntitlement({ planId: "free", usedThisMonth: 0, clipSeconds: 15, formats: ["vertical"], ...over });

ok("a normal free render is allowed", free({}).allowed);
ok("a 60s clip is refused on Free", !free({ clipSeconds: 60 }).allowed);
ok("...and the reason names Pro", /Pro/.test(free({ clipSeconds: 60 }).reason ?? ""));
ok("60s is allowed on Pro",
  checkEntitlement({ planId: "pro", usedThisMonth: 0, clipSeconds: 60, formats: ["wide"] }).allowed);

ok("running out is refused", !free({ usedThisMonth: 5 }).allowed);
ok("...and says failures are free",
  /failed/i.test(free({ usedThisMonth: 5 }).reason ?? ""), free({ usedThisMonth: 5 }).reason);
ok("remaining never goes negative", free({ usedThisMonth: 99 }).remaining === 0);
ok("remaining is reported for the UI", free({ usedThisMonth: 2 }).remaining === 3);

console.log("");
console.log("unknown input falls back rather than throwing:");
ok("unknown plan id -> Free", getPlan("enterprise").id === "free");
ok("null plan id -> Free", getPlan(null).id === "free");
ok("an unknown format is refused",
  !checkEntitlement({ planId: "pro", usedThisMonth: 0, clipSeconds: 15, formats: ["hologram"] }).allowed);

console.log(failures === 0 ? "\nPASS — entitlements match the plan" : `\nFAIL — ${failures}`);
process.exit(failures === 0 ? 0 : 1);
