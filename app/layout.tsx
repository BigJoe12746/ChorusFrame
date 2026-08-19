import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://verseframe.vercel.app"),
  openGraph: {
    siteName: "ChorusFrame",
    type: "website",
    title: "ChorusFrame - Upload one song, get your release clips",
    description:
      "Vertical, square and widescreen cuts from one project, timed to your song.",
  },
  twitter: { card: "summary_large_image" },
  title: "ChorusFrame — Upload one song, get your entire release campaign",
  description:
    "Song, cover, and lyrics in — vertical, square and widescreen cuts out, timed to your music. One project, three formats, in minutes.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
