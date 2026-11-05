const RELEASE_META = /<meta\s+name="release-sha"\s+content="([0-9a-f]{7,40}|dev)"\s*\/?>/i;

export function readReleaseSha(html: string): string | null {
  return html.match(RELEASE_META)?.[1] ?? null;
}

export function currentReleaseSha(doc: Pick<Document, "querySelector">): string {
  return doc.querySelector<HTMLMetaElement>('meta[name="release-sha"]')?.content ?? "dev";
}

export async function fetchActiveReleaseSha(fetchFn: typeof fetch = fetch): Promise<string | null> {
  const res = await fetchFn("/index.html", { cache: "no-store" });
  if (!res.ok) return null;
  return readReleaseSha(await res.text());
}

export interface WatcherOptions {
  currentSha: string;
  intervalMs: number;
  fetchSha: () => Promise<string | null>;
  reload: () => void;
  setTimer?: (fn: () => void, ms: number) => unknown;
}

export function startReleaseWatcher(options: WatcherOptions): () => void {
  const setTimer = options.setTimer ?? ((fn: () => void, ms: number) => setTimeout(fn, ms));
  let stopped = false;
  const tick = async (): Promise<void> => {
    if (stopped) return;
    const active = await options.fetchSha().catch(() => null);
    if (active !== null && active !== options.currentSha) {
      options.reload();
      return;
    }
    setTimer(() => void tick(), options.intervalMs);
  };
  setTimer(() => void tick(), options.intervalMs);
  return () => {
    stopped = true;
  };
}

export type ReloadMemory = Pick<Storage, "getItem" | "setItem">;

export function reloadOnChunkError(
  target: Pick<Window, "addEventListener">,
  reload: () => void,
  memory: ReloadMemory,
  sha: string,
): void {
  const key = `chunk-reload:${sha}`;
  target.addEventListener("vite:preloadError", (event) => {
    if (memory.getItem(key) !== null) return;
    memory.setItem(key, new Date().toISOString());
    event.preventDefault();
    reload();
  });
}
