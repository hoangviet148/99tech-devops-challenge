import { defineConfig } from "vitest/config";

process.env.VITE_RELEASE_SHA ??= "dev";

export default defineConfig({
  build: {
    manifest: true,
    sourcemap: false,
    target: "es2022",
  },
  test: {
    environment: "node",
  },
});
