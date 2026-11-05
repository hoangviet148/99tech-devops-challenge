import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

RELEASE = "/opt/backend/current/version.json"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self.reply({"status": "ok"})
        elif self.path == "/version":
            with open(RELEASE) as f:
                served = json.load(f)
            override = "/run/fake-systemd/serve-sha"
            if os.path.exists(override):
                with open(override) as f:
                    served["sha"] = f.read().strip()
            self.reply(served)
        else:
            self.send_error(404)

    def reply(self, body):
        data = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
