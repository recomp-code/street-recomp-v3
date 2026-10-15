#!/usr/bin/env python3
"""Receives the browser build's "Enviar diagnóstico" reports (POST /diag) and keeps the last 50."""
import os, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DIR = os.environ.get("STATE_DIRECTORY", "/var/lib/nbarecomp-diag")
LIMIT = 4 << 20

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        if self.path != "/diag" or length <= 0 or length > LIMIT:
            self.send_response(400); self.end_headers(); return
        body = self.rfile.read(length)
        name = time.strftime("%Y%m%d-%H%M%S") + ".txt"
        with open(os.path.join(DIR, name), "wb") as f:
            f.write(body)
        files = sorted(os.listdir(DIR))
        for old in files[:-50]:
            os.remove(os.path.join(DIR, old))
        self.send_response(200); self.send_header("Content-Type", "text/plain"); self.end_headers()
        self.wfile.write(name.encode())
    def log_message(self, *args):
        pass

ThreadingHTTPServer(("127.0.0.1", 8766), Handler).serve_forever()
