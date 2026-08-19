import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = "https://verseframe.vercel.app";
  const paths = ["", "/pricing", "/upload", "/login", "/legal/terms", "/legal/privacy", "/legal/copyright"];
  return paths.map((path) => ({ url: `${base}${path}`, changeFrequency: "weekly" as const }));
}
