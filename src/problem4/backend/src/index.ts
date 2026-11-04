import { createServer } from "./app.js";
import { loadVersion } from "./version.js";

const port = Number(process.env.PORT ?? 8080);
const allowedOrigins = new Set(
  (process.env.ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
);
const version = loadVersion();
const server = createServer({ version, allowedOrigins });

function log(level: string, msg: string, fields: Record<string, unknown> = {}): void {
  process.stdout.write(`${JSON.stringify({ time: new Date().toISOString(), level, msg, ...fields })}\n`);
}

function shutdown(signal: string): void {
  log("info", "shutdown started", { signal });
  setTimeout(() => process.exit(1), 10000).unref();
  server.close(() => process.exit(0));
  server.closeIdleConnections();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

server.listen(port, () => log("info", "backend listening", { port, sha: version.sha }));
