import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { it } from "node:test";
import { loadVersion } from "../src/version.js";

it("reads the version written at build time", () => {
  const file = join(mkdtempSync(join(tmpdir(), "backend-version-")), "version.json");
  writeFileSync(file, JSON.stringify({ sha: "def456", committed_at: "2026-11-04T01:02:03Z" }));
  assert.deepEqual(loadVersion(file), { sha: "def456", committed_at: "2026-11-04T01:02:03Z" });
});

it("falls back to GIT_SHA when no version file exists", () => {
  process.env.GIT_SHA = "fallback";
  assert.deepEqual(loadVersion("/nonexistent/version.json"), { sha: "fallback", committed_at: null });
  delete process.env.GIT_SHA;
});
