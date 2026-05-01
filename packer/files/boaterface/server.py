#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timezone
from pathlib import Path

STATIC = Path('/usr/local/lib/boaterface')

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/time':
            self.serve_time()
        elif self.path == '/htmx.min.js':
            self.serve_file('htmx.min.js', 'application/javascript')
        elif self.path in ('/', '/index.html'):
            self.serve_file('index.html', 'text/html')
        else:
            self.send_response(404)
            self.end_headers()

    def serve_time(self):
        body = datetime.now(timezone.utc).strftime('%H:%M:%S').encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)

    def serve_file(self, name, content_type):
        data = (STATIC / name).read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', len(data))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass

HTTPServer(('', 80), Handler).serve_forever()
