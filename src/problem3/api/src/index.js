const crypto = require("crypto");
const express = require("express");
const { Pool } = require("pg");
const Redis = require("ioredis");

const PORT = Number(process.env.PORT || 3000);
const POOL_MAX = Number(process.env.PG_POOL_MAX || 4);
const REQUEST_DEADLINE_MS = 2000;
const QUERY_MARGIN_MS = 100;
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

function log(level, msg, fields = {}) {
  process.stdout.write(`${JSON.stringify({ time: new Date().toISOString(), level, msg, ...fields })}\n`);
}

const pool = new Pool({
  host: process.env.DB_HOST,
  user: "postgres",
  password: "postgres",
  database: "postgres",
  port: 5432,
  max: POOL_MAX,
  connectionTimeoutMillis: 1000,
  idleTimeoutMillis: 30000,
  statement_timeout: 1000,
  application_name: "api",
});
pool.on("error", (err) => log("warn", "idle database client failed", { error: err.message }));

const redis = new Redis({ host: process.env.REDIS_HOST, port: 6379 });

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

const app = express();
app.disable("x-powered-by");

app.use((req, res, next) => {
  req.id = req.get("x-request-id") || crypto.randomUUID();
  res.set("X-Request-ID", req.id);
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
    await redis.set("last_call", Date.now());
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

app.get("/status", (req, res) => res.json({ status: "ok" }));

app.use((err, req, res, next) => {
  log("error", "unhandled request error", { request_id: req.id, error: err.message });
  if (res.headersSent) return next(err);
  return res.status(500).json({ ok: false, error: "internal_error", request_id: req.id });
});

app.listen(PORT, () => log("info", "api listening", { port: PORT }));
