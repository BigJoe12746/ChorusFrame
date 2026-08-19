import type { Metadata } from "next";

export const metadata: Metadata = { title: "Log in — ChorusFrame" };

export default function LoginLayout({ children }: LayoutProps<"/login">) {
  return children;
}
