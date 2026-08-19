import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "ChorusFrame",
    short_name: "ChorusFrame",
    description: "Upload one song, get your release clips.",
    start_url: "/dashboard",
    display: "standalone",
    background_color: "#080b16",
    theme_color: "#080b16",
    icons: [{ src: "/icon.svg", sizes: "any", type: "image/svg+xml" }],
  };
}
