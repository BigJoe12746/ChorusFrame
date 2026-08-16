import type { Metadata } from "next";
import Link from "next/link";
import { LEGAL_CONTACT, LEGAL_UPDATED } from "../contact";

export const metadata: Metadata = {
  title: "Privacy — ChorusFrame",
  description: "What ChorusFrame collects, where it goes, and how to get it deleted.",
};

export default function PrivacyPage() {
  return (
    <>
      <h1>Privacy</h1>
      <p className="text-sm">Last updated {LEGAL_UPDATED}</p>

      <p>
        This describes what ChorusFrame actually stores and who it is shared with. If
        something here doesn&apos;t match what the product does, treat that as a bug and
        tell us.
      </p>

      <h2>What we collect</h2>
      <ul>
        <li>
          <strong>Your account:</strong> the email address you sign in with, and an
          artist name if you give one. We use passwordless sign-in links, so we never
          hold a password for you.
        </li>
        <li>
          <strong>What you upload:</strong> your audio file, cover artwork if you add
          one, the song title, and any lyrics you paste.
        </li>
        <li>
          <strong>Render records:</strong> which clips you asked for, when, which
          visual style, whether the render succeeded, and any error message.
        </li>
      </ul>
      <p>
        We don&apos;t use analytics or advertising trackers, and there are no third-party
        cookies. The only cookie we set is the one that keeps you signed in.
      </p>

      <h2>Where it goes</h2>
      <ul>
        <li>
          <strong>Supabase</strong> stores the database and your files.
        </li>
        <li>
          <strong>Vercel</strong> serves the website.
        </li>
        <li>
          <strong>Railway</strong> runs the process that renders your clips.
        </li>
        <li>
          <strong>A transcription provider</strong> (OpenAI or Deepgram) receives a copy
          of your audio <em>only</em> when we align pasted lyrics to it, so we can tell
          when each line is sung. If you don&apos;t paste lyrics, your audio is never
          sent to them.
        </li>
        <li>
          <strong>An email provider</strong> (Resend or Postmark) receives your email
          address to send you sign-in links and a message when your clips are ready.
        </li>
      </ul>

      <h2>Who can see your files</h2>
      <p>
        Your uploaded audio and artwork are stored privately. Reading them requires a
        short-lived signed link that only our own systems generate.
      </p>
      <p>
        <strong>Finished clips are different.</strong> They live at public web addresses
        so you can share them and so they play in a preview. The addresses contain a
        random identifier and aren&apos;t listed anywhere, but anyone who has the link
        can watch the clip. Treat a clip link like a shared file, not a secret.
      </p>

      <h2>We don&apos;t train on your music</h2>
      <p>
        Your songs, artwork and lyrics are not used to train machine-learning models,
        by us or by anyone we send them to, and we don&apos;t sell or rent your data.
      </p>

      <h2>Keeping and deleting</h2>
      <p>
        We keep your uploads and clips while your account exists, so you can come back
        to them. Ask us and we will delete your account, your uploads and your clips.
        Email <a href={`mailto:${LEGAL_CONTACT}`}>{LEGAL_CONTACT}</a> and say what you
        want removed.
      </p>
      <p>
        Depending on where you live you may have rights to access, correct, export or
        delete your personal data. The same address handles those requests.
      </p>

      <h2>Children</h2>
      <p>ChorusFrame isn&apos;t intended for anyone under 13.</p>

      <h2>Changes</h2>
      <p>
        If this changes in a way that matters, we&apos;ll update the date at the top and
        tell account holders by email.
      </p>

      <p>
        See also our <Link href="/legal/terms">Terms</Link> and{" "}
        <Link href="/legal/copyright">Copyright policy</Link>.
      </p>
    </>
  );
}
