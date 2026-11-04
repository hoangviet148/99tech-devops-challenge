import { describe, expect, it } from "vitest";
import {
  currentReleaseSha,
  fetchActiveReleaseSha,
  readReleaseSha,
  reloadOnChunkError,
  startReleaseWatcher,
} from "../src/release";

const page = (sha: string) => `<html><head><meta name="release-sha" content="${sha}" /></head></html>`;

function manualTimers() {
  const queue: (() => void)[] = [];
  return {
    setTimer: (fn: () => void) => {
      queue.push(fn);
    },
    async runNext() {
      const fn = queue.shift();
      if (fn) fn();
      await new Promise((resolve) => setTimeout(resolve, 0));
    },
    pending: () => queue.length,
  };
}

describe("release detection", () => {
  it("reads the release SHA from the activation object", () => {
    expect(readReleaseSha(page("0123456789abcdef0123456789abcdef01234567"))).toBe(
      "0123456789abcdef0123456789abcdef01234567",
    );
    expect(readReleaseSha("<html></html>")).toBeNull();
    expect(readReleaseSha(page("not-a-sha"))).toBeNull();
  });

  it("falls back to dev when the page has no release meta", () => {
    expect(currentReleaseSha({ querySelector: () => null } as unknown as Document)).toBe("dev");
  });

  it("fetches index.html without the HTTP cache", async () => {
    let seen: RequestInit | undefined;
    const sha = await fetchActiveReleaseSha(async (_url, init) => {
      seen = init;
      return new Response(page("aaaaaaa"));
    });
    expect(sha).toBe("aaaaaaa");
    expect(seen?.cache).toBe("no-store");
  });

  it("reloads once the active release differs, which covers activation and rollback alike", async () => {
    const timers = manualTimers();
    const answers = ["aaaaaaa", "bbbbbbb"];
    let reloads = 0;
    startReleaseWatcher({
      currentSha: "aaaaaaa",
      intervalMs: 1000,
      fetchSha: async () => answers.shift() ?? null,
      reload: () => {
        reloads += 1;
      },
      setTimer: timers.setTimer,
    });
    await timers.runNext();
    expect(reloads).toBe(0);
    await timers.runNext();
    expect(reloads).toBe(1);
    expect(timers.pending()).toBe(0);
  });

  it("keeps polling when a check fails", async () => {
    const timers = manualTimers();
    let reloads = 0;
    startReleaseWatcher({
      currentSha: "aaaaaaa",
      intervalMs: 1000,
      fetchSha: async () => {
        throw new Error("network down");
      },
      reload: () => {
        reloads += 1;
      },
      setTimer: timers.setTimer,
    });
    await timers.runNext();
    expect(reloads).toBe(0);
    expect(timers.pending()).toBe(1);
  });

  it("reloads once per release on a chunk error, then lets the error surface", () => {
    let handler: ((event: Event) => void) | undefined;
    const target = {
      addEventListener: (_type: string, fn: (event: Event) => void) => {
        handler = fn;
      },
    } as unknown as Pick<Window, "addEventListener">;
    const store = new Map<string, string>();
    const memory = { getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => store.set(k, v) };
    let reloads = 0;
    reloadOnChunkError(target, () => (reloads += 1), memory, "aaaaaaa");
    const first = new Event("vite:preloadError", { cancelable: true });
    handler?.(first);
    expect(reloads).toBe(1);
    expect(first.defaultPrevented).toBe(true);
    const second = new Event("vite:preloadError", { cancelable: true });
    handler?.(second);
    expect(reloads).toBe(1);
    expect(second.defaultPrevented).toBe(false);
  });
});
