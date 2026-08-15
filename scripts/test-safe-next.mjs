// Guard tests for the auth redirect sanitizer.
//   node scripts/test-safe-next.mjs
//
// Every attack must resolve to a same-origin location BOTH after resolveNext
// and after the result is re-parsed the way NextResponse.redirect does.

import { resolveNext } from "../lib/safe-next.ts";

const ORIGIN = "https://verseframe.vercel.app";
const BS = String.fromCharCode(92); // backslash, kept out of shell quoting
const TAB = String.fromCharCode(9);
const LF = String.fromCharCode(10);
const CR = String.fromCharCode(13);

const attacks = [
  [`/${BS}evil.com`, "backslash"],
  [`/${BS}/evil.com`, "backslash-slash"],
  [`${BS}${BS}evil.com`, "double backslash"],
  [`/${TAB}/evil.com`, "tab"],
  [`/${LF}/evil.com`, "newline"],
  [`/${CR}/evil.com`, "carriage return"],
  ["//evil.com", "protocol-relative"],
  ["///evil.com", "triple slash"],
  ["/..//evil.com", "traversal to protocol-relative"],
  ["/../..//evil.com", "deep traversal"],
  ["https://evil.com/steal", "absolute"],
  ["http://evil.com", "absolute http"],
  ["javascript:alert(1)", "javascript scheme"],
  ["data:text/html,<script>alert(1)</script>", "data scheme"],
  [`https://verseframe.vercel.app.evil.com/x`, "suffix lookalike host"],
  [`https://evil.com${BS}@verseframe.vercel.app/`, "userinfo confusion"],
];

const legit = [
  ["/dashboard", "/dashboard"],
  ["/dashboard?tab=clips", "/dashboard?tab=clips"],
  ["/dashboard#top", "/dashboard#top"],
  ["/upload", "/upload"],
  [null, "/dashboard"],
  ["", "/dashboard"],
];

let failures = 0;

console.log("ATTACKS — must never leave the origin:");
for (const [input, name] of attacks) {
  const out = resolveNext(input, ORIGIN);
  // Re-parse exactly like NextResponse.redirect(new URL(out, origin)) does
  let finalOrigin;
  try {
    finalOrigin = new URL(out, ORIGIN).origin;
  } catch {
    finalOrigin = "<unparseable>";
  }
  const leaked = finalOrigin !== ORIGIN;
  if (leaked) failures++;
  console.log(
    `  ${leaked ? "LEAK " : "safe "} ${name.padEnd(30)} -> ${String(out).padEnd(26)} (${finalOrigin})`
  );
}

console.log("\nLEGITIMATE — must be preserved:");
for (const [input, want] of legit) {
  const out = resolveNext(input, ORIGIN);
  const ok = out === want;
  if (!ok) failures++;
  console.log(`  ${ok ? "ok   " : "WRONG"} ${JSON.stringify(input).padEnd(24)} -> ${out}`);
}

console.log(failures === 0 ? "\nPASS — all vectors contained" : `\nFAIL — ${failures} problem(s)`);
process.exit(failures === 0 ? 0 : 1);
