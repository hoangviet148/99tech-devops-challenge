import contract from "../contract.json";

export const MIN_BACKEND_API: number = contract.min_backend_api;
export const GREETING_PATH = "/api/v1/greeting";
export const GREETING_FIELDS = ["message", "served_at"] as const;

export interface Greeting {
  message: string;
  served_at: string;
}

export async function getGreeting(baseUrl: string, name: string, fetchFn: typeof fetch = fetch): Promise<Greeting> {
  const url = new URL(GREETING_PATH, baseUrl);
  url.searchParams.set("name", name);
  const res = await fetchFn(url, { headers: { accept: "application/json" } });
  if (!res.ok) throw new Error(`greeting request failed with ${res.status}`);
  const body = (await res.json()) as Record<string, unknown>;
  for (const field of GREETING_FIELDS) {
    if (typeof body[field] !== "string") throw new Error(`greeting response lacks ${field}`);
  }
  return { message: String(body.message), served_at: String(body.served_at) };
}
