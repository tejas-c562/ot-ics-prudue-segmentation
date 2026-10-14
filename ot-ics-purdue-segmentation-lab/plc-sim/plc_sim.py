#!/usr/bin/env python3
"""
Simulated water-tank PLC speaking Modbus/TCP on port 502.

Why a simulator? It makes the lab 100% reproducible without third-party images and
generates realistic, deterministic Modbus traffic for the detection project (02).
The OpenPLC runtime can be used instead via `--profile openplc` (see README).

Register map (unit id 1)
  Coils (FC1/5/15)          0  PUMP_RUN        1 = fill pump on
                            1  ALARM_HIGH      1 = high level alarm (read-only by convention)
  Holding regs (FC3/6/16)   0  LEVEL_SETPOINT  % (default 60)
                            1  LEVEL_PV        process value, % x 10 (simulated)
                            2  PUMP_SPEED_CMD  % (default 50)
"""
import asyncio, logging, os
from pymodbus.server import StartAsyncTcpServer
from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"),
                    format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("plc")

COIL_PUMP, COIL_ALARM = 0, 1
HR_SETPOINT, HR_LEVEL, HR_SPEED = 0, 1, 2


async def process_loop(ctx: ModbusSlaveContext):
    """Tiny physical model: pump on -> level rises, pump off -> level falls."""
    level = 500.0  # 50.0 %
    while True:
        pump = ctx.getValues(1, COIL_PUMP, 1)[0]
        sp, speed = ctx.getValues(3, HR_SETPOINT, 1)[0], ctx.getValues(3, HR_SPEED, 1)[0]
        level += (0.08 * speed) if pump else -3.0
        level = max(0.0, min(1000.0, level))
        if level >= (sp + 10) * 10:          # local control logic (hysteresis)
            ctx.setValues(1, COIL_PUMP, [0])
        elif level <= (sp - 10) * 10:
            ctx.setValues(1, COIL_PUMP, [1])
        ctx.setValues(3, HR_LEVEL, [int(level)])
        ctx.setValues(1, COIL_ALARM, [1 if level > 900 else 0])
        await asyncio.sleep(1)


async def main():
    store = ModbusSlaveContext(
        co=ModbusSequentialDataBlock(0, [0] * 16),
        hr=ModbusSequentialDataBlock(0, [60, 500, 50] + [0] * 13),
        di=ModbusSequentialDataBlock(0, [0] * 16),
        ir=ModbusSequentialDataBlock(0, [0] * 16),
        zero_mode=True,   # pymodbus quirk: without this, address N maps to index N+1
    )
    context = ModbusServerContext(slaves={1: store}, single=False)
    asyncio.create_task(process_loop(store))
    log.info("PLC simulator listening on 0.0.0.0:502")
    await StartAsyncTcpServer(context=context, address=("0.0.0.0", 502))


if __name__ == "__main__":
    asyncio.run(main())
