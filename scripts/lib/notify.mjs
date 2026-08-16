// "Your clips are ready" email.
//
// Self-serve rendering is only self-serve if the artist doesn't have to sit on
// the dashboard watching a spinner. Provider is chosen by whichever key is
// present; with none configured this logs what it would have sent, so a
// missing key never blocks a render.

const BRAND = { bg: "#080b16", card: "#0e1326", text: "#eef0f8", muted: "#8b93b5", cyan: "#22dcf5" };

const FORMAT_LABELS = {
  vertical: "9:16 vertical — TikTok, Reels, Shorts",
  square: "1:1 square — feed posts",
  wide: "16:9 wide — YouTube",
};

function getProvider(env) {
  if (env.RESEND_API_KEY) return resend(env.RESEND_API_KEY, env);
  if (env.POSTMARK_TOKEN) return postmark(env.POSTMARK_TOKEN, env);
  return null;
}

function resend(apiKey, env) {
  return {
    name: "resend",
    async send({ to, subject, html, text }) {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          from: env.NOTIFY_FROM || "ChorusFrame <onboarding@resend.dev>",
          to: [to],
          subject,
          html,
          text,
        }),
      });
      if (!res.ok) throw new Error(`${res.status}: ${(await res.text()).slice(0, 180)}`);
    },
  };
}

function postmark(token, env) {
  return {
    name: "postmark",
    async send({ to, subject, html, text }) {
      const res = await fetch("https://api.postmarkapp.com/email", {
        method: "POST",
        headers: {
          "X-Postmark-Server-Token": token,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          From: env.NOTIFY_FROM || "no-reply@chorusframe.app",
          To: to,
          Subject: subject,
          HtmlBody: html,
          TextBody: text,
          MessageStream: "outbound",
        }),
      });
      if (!res.ok) throw new Error(`${res.status}: ${(await res.text()).slice(0, 180)}`);
    },
  };
}

const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]
  );

function buildEmail({ songTitle, clips, siteUrl }) {
  const title = escapeHtml(songTitle);
  const dashboard = `${siteUrl || ""}/dashboard`;

  const rows = clips
    .map(
      (c) => `
      <tr><td style="padding:6px 0">
        <a href="${escapeHtml(c.url)}"
           style="color:${BRAND.cyan};text-decoration:none;font-size:15px">
          ${escapeHtml(FORMAT_LABELS[c.format] ?? c.format)} &rarr;
        </a>
      </td></tr>`
    )
    .join("");

  const html = `<!doctype html>
<html><body style="margin:0;padding:24px;background:${BRAND.bg};font-family:Inter,Segoe UI,Arial,sans-serif">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center">
      <table role="presentation" width="100%" style="max-width:520px" cellpadding="0" cellspacing="0">
        <tr><td style="padding-bottom:20px;color:${BRAND.muted};font-size:13px;letter-spacing:.18em;text-transform:uppercase">
          ChorusFrame
        </td></tr>
        <tr><td style="background:${BRAND.card};border-radius:16px;padding:28px">
          <h1 style="margin:0 0 8px;color:${BRAND.text};font-size:22px">Your clips are ready</h1>
          <p style="margin:0 0 20px;color:${BRAND.muted};font-size:15px;line-height:1.5">
            We finished rendering <strong style="color:${BRAND.text}">${title}</strong>.
            Grab whichever cuts you need:
          </p>
          <table role="presentation" cellpadding="0" cellspacing="0">${rows}</table>
          <p style="margin:24px 0 0">
            <a href="${escapeHtml(dashboard)}"
               style="display:inline-block;background:${BRAND.cyan};color:#04121a;text-decoration:none;
                      padding:11px 20px;border-radius:10px;font-weight:600;font-size:14px">
              Open your dashboard
            </a>
          </p>
        </td></tr>
        <tr><td style="padding-top:18px;color:${BRAND.muted};font-size:12px;line-height:1.5">
          You're getting this because you rendered a clip on ChorusFrame.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;

  const text = [
    `Your clips are ready.`,
    ``,
    `We finished rendering "${songTitle}".`,
    ``,
    ...clips.map((c) => `${FORMAT_LABELS[c.format] ?? c.format}: ${c.url}`),
    ``,
    dashboard ? `Dashboard: ${dashboard}` : "",
  ]
    .filter(Boolean)
    .join("\n");

  return { subject: `Your clips for "${songTitle}" are ready`, html, text };
}

/**
 * Tell the artist their clips are done. Never throws — a render that produced
 * real clips must not be marked failed because an email bounced.
 */
export async function notifyClipsReady({ env, to, songTitle, clips, log = console.log }) {
  if (!to || !clips?.length) return { sent: false, reason: "nothing to send" };

  const provider = getProvider(env);
  const { subject, html, text } = buildEmail({
    songTitle,
    clips,
    siteUrl: env.NEXT_PUBLIC_SITE_URL,
  });

  if (!provider) {
    log(`no email provider configured — would have emailed ${to}: ${subject}`);
    return { sent: false, reason: "no provider" };
  }

  try {
    await provider.send({ to, subject, html, text });
    log(`emailed ${to} via ${provider.name}`);
    return { sent: true, provider: provider.name };
  } catch (e) {
    log(`could not email ${to}: ${e.message}`);
    return { sent: false, reason: e.message };
  }
}
