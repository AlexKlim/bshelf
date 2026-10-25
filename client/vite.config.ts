import { createHash } from "node:crypto"
import { readFileSync, writeFileSync } from "node:fs"
import path from "path"
import react from "@vitejs/plugin-react"
import type { Plugin } from "vite"
import { defineConfig } from "vitest/config"

function versionServiceWorker(): Plugin {
  let version = ""
  let assets: string[] = []
  let outDir = ""
  return {
    name: "version-service-worker",
    apply: "build",
    generateBundle(options, bundle) {
      outDir = options.dir!
      version = createHash("sha256").update(Object.keys(bundle).sort().join()).digest("hex").slice(0, 12)
      assets = Object.keys(bundle).filter((f) => /\.(js|css)$/.test(f)).map((f) => `/${f}`)
    },
    closeBundle() {
      const file = path.join(outDir, "sw.js")
      writeFileSync(file, readFileSync(file, "utf8").replace("__BUILD__", version).replace("/* __ASSETS__ */ []", JSON.stringify(assets)))
    },
  }
}

export default defineConfig({
  plugins: [react(), versionServiceWorker()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "@design": path.resolve(__dirname, "../design"),
    },
  },
  build: {
    outDir: "../public",
    emptyOutDir: false,
  },
  server: {
    fs: { allow: [".."] },
    proxy: {
      "/api": { target: `http://localhost:${process.env.API_PORT ?? 3000}`, changeOrigin: true },
    },
  },
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: "./src/test/setup.ts",
    include: ["src/**/*.test.{ts,tsx}"],
  },
})
