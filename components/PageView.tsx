"use client";

import { usePathname } from "next/navigation";
import { useEffect, useRef } from "react";

/**
 * Reports that a page was looked at, once per path.
 *
 * The anonymous id is a random value in localStorage — it exists so a visit
 * can be joined to the signup it becomes, and for nothing else. It is not
 * derived from the browser, the network, or anything about the person, and
 * clearing site data ends it. No third-party script ever loads: the beacon
 * goes to our own route, which is why the privacy policy can keep saying
 * behaviour data stays with us.
 */
export default function PageView() {
  const pathname = usePathname();
  const lastSent = useRef<string | null>(null);

  useEffect(() => {
    if (!pathname || lastSent.current === pathname) return;
    lastSent.current = pathname;

    let anonId: string | null = null;
    for (const store of [
      () => localStorage,
      () => sessionStorage, // private mode often allows this when localStorage is blocked
    ]) {
      try {
        const s = store();
        anonId = s.getItem("cf_aid");
        if (!anonId) {
          anonId = crypto.randomUUID();
          s.setItem("cf_aid", anonId);
        }
        break;
      } catch {
        // try the next store
      }
    }

    const body = JSON.stringify({
      name: "page_view",
      path: pathname,
      anonId,
      // Where they came from, host only — never the full referring URL.
      ref: (() => {
        try {
          return document.referrer && new URL(document.referrer).host !== location.host
            ? new URL(document.referrer).host
            : "";
        } catch {
          return "";
        }
      })(),
    });

    // keepalive so the beacon survives the navigation that triggered it
    const send = (payload: string) =>
      fetch("/api/track", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: payload,
        keepalive: true,
      }).catch(() => {});

    send(body);

    /*
     * Landing on the dashboard is the first moment a brand-new account is
     * definitely signed in — including through the fragment flow, which
     * finishes in the browser and never touches the callback route. The
     * server decides whether this is actually a signup; we only say "I
     * arrived", and carry the anon id so the visit can be joined to it.
     */
    if (pathname.startsWith("/dashboard") || pathname.startsWith("/auth/complete")) {
      send(JSON.stringify({ name: "arrived", anonId }));
    }
  }, [pathname]);

  return null;
}
