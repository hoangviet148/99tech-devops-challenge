export interface RuntimeConfig {
  environment: string;
  apiBaseUrl: string;
  versionCheckSeconds: number;
}

const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1"]);

export function parseConfig(raw: unknown): RuntimeConfig {
  if (typeof raw !== "object" || raw === null) throw new Error("config is not an object");
  const { environment, apiBaseUrl, versionCheckSeconds } = raw as Record<string, unknown>;
  if (typeof environment !== "string" || environment.length === 0) throw new Error("config.environment is missing");
  if (typeof apiBaseUrl !== "string") throw new Error("config.apiBaseUrl is missing");
  const url = new URL(apiBaseUrl);
  if (url.protocol !== "https:" && !(url.protocol === "http:" && LOCAL_HOSTS.has(url.hostname))) {
    throw new Error("config.apiBaseUrl must use https outside localhost");
  }
  if (typeof versionCheckSeconds !== "number" || !Number.isInteger(versionCheckSeconds)) {
    throw new Error("config.versionCheckSeconds must be an integer");
  }
  if (versionCheckSeconds < 1 || versionCheckSeconds > 3600) {
    throw new Error("config.versionCheckSeconds must lie between 1 and 3600");
  }
  return { environment, apiBaseUrl: url.origin, versionCheckSeconds };
}

export async function loadConfig(sha: string, fetchFn: typeof fetch = fetch): Promise<RuntimeConfig> {
  const res = await fetchFn(`/releases/${sha}/config.json`, { cache: "no-cache" });
  if (!res.ok) throw new Error(`config request failed with ${res.status}`);
  return parseConfig(await res.json());
}
