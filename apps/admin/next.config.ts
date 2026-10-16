import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  // Admin is deployed as a static site; image URLs come from the API/Drive.
  images: { unoptimized: true },
};

export default nextConfig;
