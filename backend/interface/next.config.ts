import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async rewrites() {
    return [
      {
        // a call in browser to "/admin-api/X" will hit this rewrite
        source: '/admin-api/:path*',
        destination: (process.env.BACKEND_URL || 'http://activity-log:8081') + '/admin/:path*',
      },
    ];
  },
};


export default nextConfig;
