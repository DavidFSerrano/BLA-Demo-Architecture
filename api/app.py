#!/usr/bin/env python3
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from datetime import datetime, timezone
from threading import Lock
from urllib.parse import urlparse

SLOTS = [
    "2026-10-06T15:00:00Z",
    "2026-10-06T16:00:00Z",
    "2026-10-06T17:00:00Z",
    "2026-10-06T18:00:00Z",
    "2026-10-06T19:00:00Z",
    "2026-10-06T20:00:00Z",
]

_lock = Lock()
_by_id = {}
_by_slot = {}
_next = 0


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            self._send(200, {"service": "booking-api"})
            return
        if path == "/health":
            self._send(200, {"status": "ok"})
            return
        if path == "/metrics":
            self._metrics()
            return
        if path == "/availability":
            with _lock:
                open_slots = [slot for slot in SLOTS if slot not in _by_slot]
            self._send(200, {"slots": open_slots})
            return
        if path == "/appointments":
            with _lock:
                rows = list(_by_id.values())
            self._send(200, {"appointments": rows})
            return
        prefix = "/appointments/"
        if path.startswith(prefix) and path.count("/") == 2:
            appointment_id = path[len(prefix) :]
            with _lock:
                row = _by_id.get(appointment_id)
            if row is None:
                self._send(404, {"error": "appointment not found"})
                return
            self._send(200, row)
            return
        self._send(404, {"error": "not found"})

    def do_POST(self):
        if urlparse(self.path).path != "/appointments":
            self._send(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        if length > 1 << 20:
            self._send(400, {"error": "body too large"})
            return
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._send(400, {"error": "invalid JSON"})
            return

        name = str(body.get("customer_name", "")).strip()
        slot = body.get("slot")
        if not name or len(name) > 200:
            self._send(400, {"error": "customer_name is required"})
            return
        if slot not in SLOTS:
            self._send(400, {"error": "unknown slot"})
            return

        global _next
        with _lock:
            if slot in _by_slot:
                self._send(409, {"error": "slot already booked"})
                return
            _next += 1
            row = {
                "id": f"apt-{_next}",
                "customer_name": name,
                "slot": slot,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
            _by_id[row["id"]] = row
            _by_slot[slot] = row["id"]
        self._send(201, row)

    def _metrics(self):
        with _lock:
            appointments = len(_by_id)
        body = (
            "# HELP booking_appointments Appointments stored in this process.\n"
            "# TYPE booking_appointments gauge\n"
            f"booking_appointments {appointments}\n"
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} {fmt % args}", flush=True)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
