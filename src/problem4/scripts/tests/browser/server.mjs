import { createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { extname, join, normalize } from "node:path";

const root = process.env.BUCKET_DIR;
const port = Number(process.env.PORT ?? 4173);
const csp = process.env.CONTENT_SECURITY_POLICY;
if (!root || !csp) throw new Error("BUCKET_DIR and CONTENT_SECURITY_POLICY are required");
const releasePage = /^\/releases\/.+\/index\.html$/;
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".json": "application/json", ".css": "text/css" };

function objectFor(pathname) {
  if (releasePage.test(decodeURIComponent(pathname))) return null;
  if (pathname === "/" || extname(pathname) === "") return "index.html";
  return normalize(pathname).replace(/^(\.\.[/\\])+/, "").replace(/^\/+/, "");
}

createServer((req, res) => {
  const url = new URL(req.url ?? "/", `http://127.0.0.1:${port}`);
  res.setHeader("content-security-policy", csp);
  if (url.pathname === "/api/v1/greeting") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ message: `Hello, ${url.searchParams.get("name")}`, served_at: new Date().toISOString() }));
    return;
  }
  let key;
  let size;
  try {
    key = objectFor(url.pathname);
    if (key === null) throw new Error("release pages are not served");
    size = statSync(join(root, key)).size;
  } catch {
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("not found\n");
    return;
  }
  const cache = key.startsWith("assets/") ? "public, max-age=31536000, immutable" : "no-cache";
  res.writeHead(200, { "content-type": types[extname(key)] ?? "application/octet-stream", "content-length": size, "cache-control": cache });
  createReadStream(join(root, key)).pipe(res);
}).listen(port, "127.0.0.1");
