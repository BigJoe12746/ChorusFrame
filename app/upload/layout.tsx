import type { Metadata } from "next";

export const metadata: Metadata = { title: "Upload a song — ChorusFrame" };

export default function UploadLayout({ children }: LayoutProps<"/upload">) {
  return children;
}
