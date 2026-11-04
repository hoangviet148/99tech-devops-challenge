import { createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";

const root = process.env.BUCKET_DIR;
const port = Number(process.env.PORT ?? 4173);
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".json": "application/json", ".css": "text/css" };

function objectFor(pathname) {
  if (pathname === "/" || extname(pathname) === "") return "index.html";
  return normalize(pathname).replace(/^(\.\.[/\\])+/, "").replace(/^\/+/, "");
}

createServer((req, res) => {
  const url = new URL(req.url ?? "/", `http://127.0.0.1:${port}`);
  if (url.pathname === "/api/v1/greeting") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ message: `Hello, ${url.searchParams.get("name")}`, served_at: new Date().toISOString() }));
    return;
  }
  const key = objectFor(url.pathname);
  const file = join(root, key);
  let size;
  try {
    size = statSync(file).size;
  } catch {
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("not found\n");
    return;
  }
  const cache = key.startsWith("assets/") ? "public, max-age=31536000, immutable" : "no-cache";
  res.writeHead(200, { "content-type": types[extname(key)] ?? "application/octet-stream", "content-length": size, "cache-control": cache });
  createReadStream(file).pipe(res);
}).listen(port, "127.0.0.1");
