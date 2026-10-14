#!/usr/bin/env python3
"""
Level-2 HMI/SCADA stand-in (inside the OT zone). Legitimate control-plane behaviour:
  * polls setpoint/level/speed (FC3) and pump/alarm coils (FC1) every second
  * writes LEVEL_SETPOINT every 30 s (FC6) - the ONLY authorised writer in the lab
ScadaBR can replace this container (see README "Using ScadaBR").
"""
import os, time, logging
from pymodbus.client import ModbusTcpClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
PLC = os.getenv("PLC_HOST", "10.10.30.10")
c = ModbusTcpClient(PLC, port=502, timeout=3)
tick = 0
while True:
    try:
        if not c.connected:
            c.connect()
        hr = c.read_holding_registers(0, 3, slave=1)
        co = c.read_coils(0, 2, slave=1)
        if not hr.isError() and not co.isError():
            logging.info("SP=%s LEVEL=%.1f%% PUMP=%s ALARM=%s",
                         hr.registers[0], hr.registers[1] / 10, co.bits[0], co.bits[1])
        if tick % 30 == 0:
            c.write_register(0, 60, slave=1)   # operator setpoint (authorised write)
        tick += 1
    except Exception as e:
        logging.warning("HMI error: %s", e)
        c.close()
    time.sleep(1)
