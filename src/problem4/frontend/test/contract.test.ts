import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parse } from "yaml";
import { GREETING_FIELDS, GREETING_PATH, getGreeting, MIN_BACKEND_API } from "../src/api";

const specPath = process.env.BACKEND_OPENAPI ?? new URL("../../backend/openapi.yaml", import.meta.url).pathname;
const spec = parse(readFileSync(specPath, "utf8"));

describe("contract with the backend OpenAPI document", () => {
  it("targets a backend API version the document provides", () => {
    expect(spec.info["x-api-version"]).toBeGreaterThanOrEqual(MIN_BACKEND_API);
  });

  it("calls an operation the document defines", () => {
    expect(spec.paths[GREETING_PATH]?.get).toBeDefined();
  });

  it("reads only fields the document marks as required", () => {
    const schema = spec.paths[GREETING_PATH].get.responses["200"].content["application/json"].schema;
    for (const field of GREETING_FIELDS) {
      expect(schema.required).toContain(field);
    }
  });

  it("rejects a response that lacks a required field", async () => {
    await expect(
      getGreeting("https://api.example.com", "x", async () => Response.json({ message: "hi" })),
    ).rejects.toThrow(/served_at/);
  });
});
