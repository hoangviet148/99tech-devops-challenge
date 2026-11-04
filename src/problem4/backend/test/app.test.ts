import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import { after, before, describe, it } from "node:test";
import { API_VERSION, createServer } from "../src/app.js";

const server = createServer({
  version: { sha: "abc123", committed_at: "2026-11-04T00:00:00Z" },
  allowedOrigins: new Set(["https://app.example.test"]),
  now: () => new Date("2026-11-04T00:00:00.000Z"),
});
let base = "";

before(async () => {
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", () => resolve()));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

after(() => new Promise<void>((resolve) => server.close(() => resolve())));

describe("backend API", () => {
  it("reports health", async () => {
    const res = await fetch(`${base}/healthz`);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { status: "ok" });
  });

  it("reports the deployed version and the API contract version", async () => {
    const res = await fetch(`${base}/version`);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { sha: "abc123", committed_at: "2026-11-04T00:00:00Z", api_version: API_VERSION });
  });

  it("greets with a default name", async () => {
    const res = await fetch(`${base}/api/v1/greeting`);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { message: "Hello, world", served_at: "2026-11-04T00:00:00.000Z" });
  });

  it("rejects names outside the allowed pattern", async () => {
    const res = await fetch(`${base}/api/v1/greeting?name=${encodeURIComponent("<script>")}`);
    assert.equal(res.status, 400);
    assert.deepEqual(await res.json(), { error: "invalid_name" });
  });

  it("returns 404 for unknown paths and 405 for other methods", async () => {
    assert.equal((await fetch(`${base}/nope`)).status, 404);
    const res = await fetch(`${base}/healthz`, { method: "POST" });
    assert.equal(res.status, 405);
    assert.equal(res.headers.get("allow"), "GET, HEAD");
  });

  it("allows CORS only for configured origins", async () => {
    const allowed = await fetch(`${base}/healthz`, { headers: { origin: "https://app.example.test" } });
    assert.equal(allowed.headers.get("access-control-allow-origin"), "https://app.example.test");
    const denied = await fetch(`${base}/healthz`, { headers: { origin: "https://evil.example.test" } });
    assert.equal(denied.headers.get("access-control-allow-origin"), null);
  });

  it("never lets a cache store an API response", async () => {
    const res = await fetch(`${base}/api/v1/greeting`);
    assert.equal(res.headers.get("cache-control"), "no-store");
    assert.equal(res.headers.get("x-content-type-options"), "nosniff");
  });
});
