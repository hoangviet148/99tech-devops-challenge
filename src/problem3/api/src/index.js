const http = require("http");
const crypto = require("crypto");
const express = require("express");
const { Pool } = require("pg");
const Redis = require("ioredis");
const metrics = require("prom-client");

const PORT = Number(process.env.PORT || 3000);
const POOL_MAX = Number(process.env.PG_POOL_MAX || 4);
const REQUEST_DEADLINE_MS = 2000;
const QUERY_MARGIN_MS = 100;
const DRAIN_MS = 5000;
const HARD_STOP_MS = 8000;
const DB_UNAVAILABLE_CODES = new Set([
  "ECONNREFUSED",
  "ECONNRESET",
  "ENOTFOUND",
  "EAI_AGAIN",
  "ETIMEDOUT",
  "EPIPE",
  "DEADLINE",
  "08000",
  "08001",
  "08003",
  "08006",
  "53300",
  "57014",
  "57P01",
  "57P02",
  "57P03",
]);

const registry = new metrics.Registry();
metrics.collectDefaultMetrics({ register: registry });
const ROUTES = new Set(["/api/users", "/healthz", "/readyz", "/status", "/internal/pool", "/metrics"]);
const httpDuration = new metrics.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration by route template, method and status class",
  labelNames: ["route", "method", "status_class"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5],
  registers: [registry],
});
const redisWriteFailures = new metrics.Counter({
  name: "redis_write_failures_total",
  help: "Failed writes of last_call to Redis",
  registers: [registry],
});

function log(level, msg, fields = {}) {
  process.stdout.write(`${JSON.stringify({ time: new Date().toISOString(), level, msg, ...fields })}\n`);
}

function throttledLog(intervalMs) {
  let last = 0;
  let suppressed = 0;
  return (level, msg, fields = {}) => {
    const now = Date.now();
    if (now - last < intervalMs) {
      suppressed += 1;
      return;
    }
    log(level, msg, { ...fields, suppressed });
    last = now;
    suppressed = 0;
  };
}

const pool = new Pool({
  max: POOL_MAX,
  connectionTimeoutMillis: 1000,
  idleTimeoutMillis: 30000,
  statement_timeout: 1000,
  application_name: "api",
});
pool.on("error", (err) => log("warn", "idle database client failed", { error: err.message }));
new metrics.Gauge({
  name: "pg_pool_clients",
  help: "Database pool clients by state",
  labelNames: ["state"],
  registers: [registry],
  collect() {
    this.set({ state: "total" }, pool.totalCount);
    this.set({ state: "idle" }, pool.idleCount);
  },
});
new metrics.Gauge({
  name: "pg_pool_waiting_requests",
  help: "Requests waiting for a database pool client",
  registers: [registry],
  collect() {
    this.set(pool.waitingCount);
  },
});

const readinessPool = new Pool({
  max: 1,
  connectionTimeoutMillis: 300,
  idleTimeoutMillis: 30000,
  statement_timeout: 200,
  query_timeout: 200,
  application_name: "api-readiness",
});
readinessPool.on("error", (err) => log("warn", "idle readiness client failed", { error: err.message }));

const redisLog = throttledLog(10000);
const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: Number(process.env.REDIS_PORT || 6379),
  enableOfflineQueue: false,
  commandTimeout: 200,
  maxRetriesPerRequest: 1,
  retryStrategy: (times) => Math.min(times * 200, 2000),
});
redis.on("error", (err) => redisLog("warn", "redis connection error", { error: err.message }));

const lastCall = { inFlight: false, pending: null, failures: 0 };

function flushLastCall() {
  const value = lastCall.pending;
  lastCall.pending = null;
  lastCall.inFlight = true;
  redis
    .set("last_call", value)
    .catch((err) => {
      lastCall.failures += 1;
      redisWriteFailures.inc();
      redisLog("warn", "redis write failed", { error: err.message });
    })
    .finally(() => {
      lastCall.inFlight = false;
      if (lastCall.pending !== null) flushLastCall();
    });
}

function recordLastCall() {
  lastCall.pending = String(Date.now());
  if (!lastCall.inFlight) flushLastCall();
}

class DeadlineError extends Error {
  constructor() {
    super("request deadline exceeded");
    this.code = "DEADLINE";
  }
}

async function dbQuery(text, values, deadline) {
  const client = await pool.connect();
  const onError = (err) => log("warn", "checked-out database client failed", { error: err.message });
  client.on("error", onError);
  const remaining = deadline - Date.now() - QUERY_MARGIN_MS;
  if (remaining <= 0) {
    client.off("error", onError);
    client.release();
    throw new DeadlineError();
  }
  try {
    const result = await client.query({ text, values, query_timeout: remaining });
    client.off("error", onError);
    client.release();
    return result;
  } catch (err) {
    client.off("error", onError);
    client.release(err);
    throw err;
  }
}

function isUnavailable(err) {
  return DB_UNAVAILABLE_CODES.has(err.code) || /timeout|terminat/i.test(err.message);
}

let shuttingDown = false;
const app = express();
app.disable("x-powered-by");

app.use((req, res, next) => {
  req.id = req.get("x-request-id") || crypto.randomUUID();
  res.set("X-Request-ID", req.id);
  const stop = httpDuration.startTimer();
  res.on("finish", () => {
    const route = ROUTES.has(req.path) ? req.path : "other";
    stop({ route, method: req.method, status_class: `${Math.floor(res.statusCode / 100)}xx` });
  });
  next();
});

app.get("/api/users", async (req, res) => {
  const deadline = Date.now() + REQUEST_DEADLINE_MS;
  let answered = false;
  const timer = setTimeout(() => {
    answered = true;
    res.set("Retry-After", "1").status(503).json({ ok: false, error: "dependency_timeout", request_id: req.id });
  }, REQUEST_DEADLINE_MS);
  try {
    const result = await dbQuery("SELECT NOW()", [], deadline);
    if (answered) return;
    clearTimeout(timer);
    recordLastCall();
    res.json({ ok: true, time: result.rows[0] });
  } catch (err) {
    if (answered) return;
    clearTimeout(timer);
    const unavailable = isUnavailable(err);
    log(unavailable ? "warn" : "error", "request failed", { request_id: req.id, error: err.message, code: err.code });
    if (unavailable) res.set("Retry-After", "1");
    res
      .status(unavailable ? 503 : 500)
      .json({ ok: false, error: unavailable ? "dependency_unavailable" : "internal_error", request_id: req.id });
  }
});

app.get("/healthz", (req, res) => res.json({ status: "ok" }));
app.get("/status", (req, res) => res.json({ status: "ok" }));

let readinessCheck = null;
function checkReadiness() {
  if (!readinessCheck) {
    readinessCheck = readinessPool
      .query("SELECT 1")
      .then(
        () => true,
        () => false,
      )
      .finally(() => {
        readinessCheck = null;
      });
  }
  return readinessCheck;
}

app.get("/readyz", async (req, res) => {
  const ready = !shuttingDown && (await checkReadiness());
  res.status(ready ? 200 : 503).json({ status: ready ? "ready" : "not_ready" });
});

app.get("/internal/pool", (req, res) => {
  res.json({
    total: pool.totalCount,
    idle: pool.idleCount,
    waiting: pool.waitingCount,
    redis_write_failures: lastCall.failures,
  });
});

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", registry.contentType);
  res.send(await registry.metrics());
});

app.use((err, req, res, next) => {
  log("error", "unhandled request error", { request_id: req.id, error: err.message });
  if (res.headersSent) return next(err);
  return res.status(500).json({ ok: false, error: "internal_error", request_id: req.id });
});

const server = http.createServer(app);
// Must stay above nginx's upstream keepalive_timeout (60 s).
server.keepAliveTimeout = 65000;
server.headersTimeout = 66000;

function within(promise, ms) {
  return Promise.race([
    Promise.resolve(promise).then(
      () => true,
      () => false,
    ),
    new Promise((resolve) => {
      setTimeout(resolve, ms, false).unref();
    }),
  ]);
}

async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  log("info", "shutdown started", { signal });
  setTimeout(() => {
    log("error", "shutdown hard stop", { signal });
    process.exit(1);
  }, HARD_STOP_MS).unref();
  await within(new Promise((resolve) => server.close(resolve)), DRAIN_MS);
  server.closeAllConnections();
  await within(Promise.all([pool.end(), readinessPool.end()]), 2000);
  if (!(await within(redis.quit(), 1000))) redis.disconnect();
  log("info", "shutdown complete", { signal });
  process.exit(0);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("uncaughtException", (err) => {
  log("fatal", "uncaught exception", { error: err.message, stack: err.stack });
  process.exit(1);
});
process.on("unhandledRejection", (reason) => {
  log("fatal", "unhandled rejection", { error: String(reason) });
  process.exit(1);
});

server.listen(PORT, () => log("info", "api listening", { port: PORT }));
