import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { loadConfig, parseConfig } from "../src/config";

describe("runtime configuration", () => {
  it("accepts every committed environment file", () => {
    for (const env of ["staging", "production"]) {
      const raw = JSON.parse(readFileSync(new URL(`../config/${env}.json`, import.meta.url), "utf8"));
      expect(parseConfig(raw).environment).toBe(env);
    }
  });

  it("rejects plain HTTP outside localhost", () => {
    expect(() =>
      parseConfig({ environment: "x", apiBaseUrl: "http://api.example.com", versionCheckSeconds: 60 }),
    ).toThrow(/https/);
    expect(
      parseConfig({ environment: "x", apiBaseUrl: "http://127.0.0.1:8080", versionCheckSeconds: 60 }).apiBaseUrl,
    ).toBe("http://127.0.0.1:8080");
  });

  it("rejects an out-of-range check interval", () => {
    expect(() =>
      parseConfig({ environment: "x", apiBaseUrl: "https://a.example.com", versionCheckSeconds: 0 }),
    ).toThrow();
    expect(() =>
      parseConfig({ environment: "x", apiBaseUrl: "https://a.example.com", versionCheckSeconds: 1.5 }),
    ).toThrow();
  });

  it("loads the configuration of its own release", async () => {
    let requested = "";
    const config = await loadConfig("abc1234", async (url) => {
      requested = String(url);
      return Response.json({ environment: "staging", apiBaseUrl: "https://api.example.com", versionCheckSeconds: 600 });
    });
    expect(requested).toBe("/releases/abc1234/config.json");
    expect(config.versionCheckSeconds).toBe(600);
  });
});
