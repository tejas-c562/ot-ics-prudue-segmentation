#!/usr/bin/env python3
"""
Level-3.5 (DMZ) historian. Read-only poller of the PLC (FC3) + a tiny HTTP API on
:8081 so IT users can see process data WITHOUT ever talking to the PLC directly.
"""
import os, time, json, threading, logging
from http.server import BaseHTTPRequestHandler, HTTPServer
from pymodbus.client import ModbusTcpClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
PLC = os.getenv("PLC_HOST", "10.10.30.10")
latest = {"status": "starting"}


def poll():
    c = ModbusTcpClient(PLC, port=502, timeout=3)
    while True:
        try:
            if not c.connected:
                c.connect()
            r = c.read_holding_registers(0, 3, slave=1)
            if not r.isError():
                latest.update(status="ok", ts=time.time(), setpoint=r.registers[0],
                              level_pct=r.registers[1] / 10, pump_speed=r.registers[2])
        except Exception as e:
            latest.update(status=f"poll-error: {e}")
            c.close()
        time.sleep(5)


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps(latest).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass


threading.Thread(target=poll, daemon=True).start()
HTTPServer(("0.0.0.0", 8081), H).serve_forever()
