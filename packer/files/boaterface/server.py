#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timezone
from pathlib import Path
import struct
import threading
import time

STATIC = Path('/usr/local/lib/boaterface')
BNO_ADDR = 0x28

def _watchdog_thread():
    try:
        with open('/dev/watchdog', 'wb', buffering=0) as wdog:
            while True:
                wdog.write(b'1')
                time.sleep(5)
    except OSError:
        pass

threading.Thread(target=_watchdog_thread, daemon=True).start()

try:
    import smbus
    _bus = smbus.SMBus(3)
    _bus.write_byte_data(BNO_ADDR, 0x3D, 0x00)  # config mode
    time.sleep(0.025)
    _bus.write_byte_data(BNO_ADDR, 0x3D, 0x0C)  # NDOF fusion mode
    time.sleep(0.020)
except Exception:
    _bus = None

_COMPASS = ['N','NNE','NE','ENE','E','ESE','SE','SSE','S','SSW','SW','WSW','W','WNW','NW','NNW']

def deg_to_compass(deg):
    return _COMPASS[round(deg / 22.5) % 16]

def read_euler():
    # Returns (heading_deg, heel_deg); heading 0-360, heel signed (+= stbd)
    data = _bus.read_i2c_block_data(BNO_ADDR, 0x1A, 6)
    h, r, _p = struct.unpack('<hhh', bytes(data))
    return h / 16.0, r / 16.0

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/time':
            self.serve_time()
        elif self.path == '/heading':
            self.serve_heading()
        elif self.path == '/heel':
            self.serve_heel()
        elif self.path == '/cal':
            self.serve_cal()
        elif self.path == '/htmx.min.js':
            self.serve_file('htmx.min.js', 'application/javascript')
        elif self.path in ('/', '/index.html'):
            self.serve_file('index.html', 'text/html')
        else:
            self.send_response(404)
            self.end_headers()

    def serve_time(self):
        self.send_html(datetime.now(timezone.utc).strftime('%H:%M:%S').encode())

    def serve_heading(self):
        if _bus is None:
            self.send_html(b'--')
            return
        try:
            hdg, _ = read_euler()
            body = f'{hdg:.0f}°<br><span style="font-size:0.5em">{deg_to_compass(hdg)}</span>'
            self.send_html(body.encode())
        except Exception:
            self.send_html(b'--')

    def serve_heel(self):
        if _bus is None:
            self.send_html(b'--')
            return
        try:
            _, heel = read_euler()
            sign = '+' if heel >= 0 else ''
            self.send_html(f'{sign}{heel:.0f}°'.encode())
        except Exception:
            self.send_html(b'--')

    def serve_cal(self):
        if _bus is None:
            self.send_html('&#9679;&#9679;&#9679;'.encode())
            return
        try:
            status = _bus.read_byte_data(BNO_ADDR, 0x35)
            gyro = (status >> 4) & 0x03
            acc  = (status >> 2) & 0x03
            mag  = (status >> 0) & 0x03
            dots = ''.join(
                f'<span style="color:{"#44ff44" if s == 3 else "#333"}">&#9679;</span>'
                for s in (gyro, acc, mag)
            )
            self.send_html(dots.encode())
        except Exception:
            self.send_html(b'&#9679;&#9679;&#9679;')

    def send_html(self, body):
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
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
