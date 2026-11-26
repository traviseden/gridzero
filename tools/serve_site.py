#!/usr/bin/env python3
"""Preview Astro output with the same response headers as Cloudflare Pages."""
import argparse
import fnmatch
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1] / "dist"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--port", type=int, default=4322)
parser.add_argument("--host", default="127.0.0.1")
args = parser.parse_args()
rules = []
for line in (ROOT / "_headers").read_text().splitlines():
    if not line.strip():
        continue
    if not line.startswith(" "):
        rules.append((line, []))
    else:
        name, value = line.strip().split(":", 1)
        rules[-1][1].append((name, value.strip()))

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *arguments, **kwargs):
        super().__init__(*arguments, directory=str(ROOT), **kwargs)

    def end_headers(self):
        path = urlparse(self.path).path
        for pattern, headers in rules:
            if fnmatch.fnmatch(path, pattern):
                for name, value in headers:
                    self.send_header(name, value)
        if path == "/sw.js":
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, format, *arguments):
        # Keep automated test output focused on failures.
        if arguments and str(arguments[1] if len(arguments) > 1 else "").startswith("4"):
            super().log_message(format, *arguments)

print(f"Serving {ROOT} at http://{args.host}:{args.port}", flush=True)
ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()
