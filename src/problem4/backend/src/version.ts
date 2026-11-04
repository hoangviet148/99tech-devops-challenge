import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { Version } from "./app.js";

const DEFAULT_PATH = fileURLToPath(new URL("../../version.json", import.meta.url));

export function loadVersion(path: string = DEFAULT_PATH): Version {
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8")) as { sha?: unknown; committed_at?: unknown };
    return {
      sha: String(parsed.sha),
      committed_at: typeof parsed.committed_at === "string" ? parsed.committed_at : null,
    };
  } catch {
    return { sha: process.env.GIT_SHA ?? "dev", committed_at: null };
  }
}
