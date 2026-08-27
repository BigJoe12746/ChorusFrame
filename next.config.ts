import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    // The URLs strangers actually type. Real signup lives at /login?new=1,
    // which nobody would guess.
    return [
      { source: "/signup", destination: "/login?new=1", permanent: false },
      { source: "/register", destination: "/login?new=1", permanent: false },
    ];
  },
};

export default nextConfig;
