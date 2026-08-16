import type { Metadata } from "next";
import { LEGAL_CONTACT, LEGAL_UPDATED } from "../contact";

export const metadata: Metadata = {
  title: "Copyright — ChorusFrame",
  description: "How to report infringing material on ChorusFrame, and how to dispute a removal.",
};

export default function CopyrightPage() {
  return (
    <>
      <h1>Copyright policy</h1>
      <p className="text-sm">Last updated {LEGAL_UPDATED}</p>

      <p>
        ChorusFrame is built for artists to promote music they own. Everyone who uploads
        confirms they hold the rights. When that turns out to be untrue, this is how it
        gets fixed.
      </p>

      <h2>Reporting infringing material</h2>
      <p>
        Send a notice to <a href={`mailto:${LEGAL_CONTACT}`}>{LEGAL_CONTACT}</a>{" "}
        including:
      </p>
      <ul>
        <li>Identification of the work you say is infringed.</li>
        <li>
          The link to the material on ChorusFrame you want removed — for a clip, the
          full URL.
        </li>
        <li>Your name, address and email so we can reach you.</li>
        <li>
          A statement that you believe in good faith the use isn&apos;t authorised by
          the rights holder, their agent, or the law.
        </li>
        <li>
          A statement that the information is accurate, and — under penalty of perjury —
          that you are the rights holder or authorised to act for them.
        </li>
        <li>Your signature, physical or electronic.</li>
      </ul>

      <h2>What we do</h2>
      <p>
        We aim to review notices within a few business days. If the notice is complete
        and the claim looks valid, we remove or disable the material and tell the person
        who uploaded it, passing on your notice.
      </p>

      <h2>Disputing a removal</h2>
      <p>
        If your material was removed and you believe that was a mistake or a
        misidentification, reply to us with:
      </p>
      <ul>
        <li>Identification of what was removed and where it was.</li>
        <li>
          A statement, under penalty of perjury, that you believe in good faith it was
          removed by mistake or misidentification.
        </li>
        <li>Your name, address, email, and consent to the jurisdiction of the courts where you live.</li>
        <li>Your signature.</li>
      </ul>
      <p>
        We&apos;ll pass it to whoever complained. If they don&apos;t pursue the matter,
        we may restore the material.
      </p>

      <h2>Repeat infringers</h2>
      <p>
        Accounts that repeatedly upload material they don&apos;t have the rights to are
        terminated.
      </p>

      <h2>False claims</h2>
      <p>
        Misrepresenting that material is infringing carries legal consequences. Please be
        sure before you send a notice.
      </p>
    </>
  );
}
