import http from "node:http";

export const API_VERSION = 1;
const NAME_PATTERN = /^[\p{L}\p{N} ._-]{1,64}$/u;

export interface Version {
  sha: string;
  committed_at: string | null;
}

export interface AppOptions {
  version: Version;
  allowedOrigins?: Set<string>;
  now?: () => Date;
}

function send(res: http.ServerResponse, status: number, body: unknown, headers: Record<string, string> = {}): void {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    "content-length": String(Buffer.byteLength(payload)),
    ...headers,
  });
  res.end(payload);
}

function corsHeaders(origin: string | undefined, allowedOrigins: Set<string>): Record<string, string> {
  if (!origin || !allowedOrigins.has(origin)) return { vary: "origin" };
  return { "access-control-allow-origin": origin, vary: "origin" };
}

export function createApp({
  version,
  allowedOrigins = new Set(),
  now = () => new Date(),
}: AppOptions): http.RequestListener {
  return (req, res) => {
    const url = new URL(req.url ?? "/", "http://localhost");
    const cors = corsHeaders(req.headers.origin, allowedOrigins);
    if (req.method !== "GET" && req.method !== "HEAD") {
      send(res, 405, { error: "method_not_allowed" }, { allow: "GET, HEAD", ...cors });
      return;
    }
    switch (url.pathname) {
      case "/healthz":
        send(res, 200, { status: "ok" }, cors);
        return;
      case "/version":
        send(res, 200, { sha: version.sha, committed_at: version.committed_at, api_version: API_VERSION }, cors);
        return;
      case "/api/v1/greeting": {
        const name = url.searchParams.get("name") ?? "world";
        if (!NAME_PATTERN.test(name)) {
          send(res, 400, { error: "invalid_name" }, cors);
          return;
        }
        send(res, 200, { message: `Hello, ${name}`, served_at: now().toISOString() }, cors);
        return;
      }
      default:
        send(res, 404, { error: "not_found" }, cors);
    }
  };
}

export function createServer(options: AppOptions): http.Server {
  const server = http.createServer(createApp(options));
  // Must stay above the ALB idle timeout (60 s).
  server.keepAliveTimeout = 65000;
  server.headersTimeout = 66000;
  return server;
}
