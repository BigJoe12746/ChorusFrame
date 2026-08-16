import type { Metadata } from "next";
import Link from "next/link";
import { LEGAL_CONTACT, LEGAL_UPDATED } from "../contact";

export const metadata: Metadata = {
  title: "Terms — ChorusFrame",
  description: "The agreement for using ChorusFrame.",
};

export default function TermsPage() {
  return (
    <>
      <h1>Terms of service</h1>
      <p className="text-sm">Last updated {LEGAL_UPDATED}</p>

      <p>
        ChorusFrame turns a song you own into promotional videos. By using it you agree
        to what&apos;s below. Plain language is intended; where it&apos;s ambiguous,
        ask us rather than guess.
      </p>

      <h2>Your account</h2>
      <p>
        You need a working email address to sign in, and you&apos;re responsible for
        what happens under your account. Tell us if you think someone else is using it.
        You must be at least 13.
      </p>

      <h2>What you upload</h2>
      <p>
        You keep ownership of your music, artwork and lyrics. Nothing here transfers
        that to us.
      </p>
      <p>
        You are confirming, every time you upload, that you own or control the rights to
        that material — including any samples, features, artwork and fonts in it — and
        that making promotional videos from it doesn&apos;t break an agreement you have
        with someone else. If you can&apos;t say that honestly about a track, don&apos;t
        upload it.
      </p>
      <p>
        You grant us permission to store your files and process them for the sole
        purpose of producing your clips: decoding the audio, sending it to a
        transcription service when you ask us to time your lyrics, rendering video, and
        hosting the result so you can download and share it. That permission ends when
        the material is deleted.
      </p>
      <p>
        We do not use your music, artwork or lyrics to train machine-learning models.
      </p>

      <h2>What you get back</h2>
      <p>
        The clips are yours to use, including commercially. We may show the ChorusFrame
        end card on clips made on a free plan.
      </p>
      <p>
        Finished clips are hosted at public web addresses so they can be shared and
        previewed. Anyone with the link can watch one — see{" "}
        <Link href="/legal/privacy">Privacy</Link>.
      </p>

      <h2>Things you can&apos;t do</h2>
      <ul>
        <li>Upload material you don&apos;t have the rights to.</li>
        <li>
          Make content that impersonates a real person, or that presents someone as
          saying or performing something they didn&apos;t.
        </li>
        <li>Upload anything unlawful, or content that sexualises minors.</li>
        <li>
          Attack the service — try to break the limits, overload the render queue, or
          reach other people&apos;s accounts or files.
        </li>
      </ul>
      <p>
        We can suspend or remove an account that does these things, and we&apos;ll tell
        you why.
      </p>

      <h2>Beta, limits and availability</h2>
      <p>
        ChorusFrame is in beta and free to use, with a cap on how many renders you can
        start per day. Features may change or break. We don&apos;t promise the service
        will be available at any particular moment, and we may change limits with
        notice.
      </p>
      <p>
        If a render fails, it doesn&apos;t count against your daily limit — a render
        that produced nothing should never cost you anything.
      </p>

      <h2>Ending it</h2>
      <p>
        You can stop at any time and ask us to delete your account and files by emailing{" "}
        <a href={`mailto:${LEGAL_CONTACT}`}>{LEGAL_CONTACT}</a>. We may end or suspend
        access if you break these terms.
      </p>

      <h2>No warranty, and limits on liability</h2>
      <p>
        ChorusFrame is provided as is, without warranties. To the extent the law allows,
        we aren&apos;t liable for indirect or consequential losses, or for lost profits,
        revenue, data or goodwill. Nothing here limits liability that can&apos;t legally
        be limited.
      </p>
      <p>
        Because you are the one asserting you have the rights to what you upload, you
        agree to cover claims brought against us that arise from material you uploaded
        without those rights.
      </p>

      <h2>Copyright complaints</h2>
      <p>
        If you believe something here infringes your copyright, our{" "}
        <Link href="/legal/copyright">Copyright policy</Link> explains how to tell us.
      </p>

      <h2>Changes</h2>
      <p>
        We&apos;ll update the date above when these change, and email account holders
        about anything significant.
      </p>

      <h2>Contact</h2>
      <p>
        <a href={`mailto:${LEGAL_CONTACT}`}>{LEGAL_CONTACT}</a>
      </p>
    </>
  );
}
