import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  // Render serves the exported site as static files, so route directories
  // need an index.html for clean URLs such as /oauth/privacy/.
  trailingSlash: true,
  // Admin is deployed as a static site; image URLs come from the API/Drive.
  images: { unoptimized: true },
};

export default nextConfig;
