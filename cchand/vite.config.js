import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  // Allow the Cloudflare quick-tunnel host (cloudflared tunnel --url
  // http://localhost:5173) to reach the dev server for remote testing.
  server: {
    allowedHosts: [".trycloudflare.com"],
  },
  plugins: [
    tailwindcss(),
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["favicon.svg", "apple-touch-icon.png"],
      manifest: {
        name: "CCC Hand Logger",
        short_name: "CCHand",
        description: "Log live poker hands fast — board, hero cards, and showdown reveals.",
        theme_color: "#14342b",
        background_color: "#0e241d",
        display: "standalone",
        orientation: "portrait",
        icons: [
          { src: "icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "icon-512.png", sizes: "512x512", type: "image/png" },
          { src: "icon-512-maskable.png", sizes: "512x512", type: "image/png", purpose: "maskable" }
        ]
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,svg,png,woff2}"]
      }
    })
  ]
});
