# Zone & Conduit Design (IEC 62443-3-2 style)

## Zones

| Zone | Purdue level | Subnet | Assets | Target SL (SL-T) | Rationale |
|------|--------------|--------|--------|------------------|-----------|
| Z-IT  | L4/L5 | 10.10.10.0/24 | Corporate workstations (`it-ws`) | SL 1 | Standard enterprise risk, internet-exposed |
| Z-DMZ | L3.5  | 10.10.20.0/24 | Historian (`historian`) | SL 2 | Only zone allowed to bridge IT and OT data |
| Z-OT  | L0-L3 | 10.10.30.0/24 | PLC (`plc`), HMI/SCADA (`hmi`) | SL 2 (SL 3 for safety-relevant) | Process control; loss = physical consequence |

## Conduits (the ONLY permitted inter-zone flows)

| ID | From | To | Protocol / port | Direction | Why it exists |
|----|------|----|-----------------|-----------|---------------|
| C1 | IT workstations | Historian (10.10.20.10) | TCP 8081 | IT -> DMZ | Business users view process data |
| C2 | Historian (10.10.20.10) | PLC (10.10.30.10) | TCP 502 (Modbus/TCP) | DMZ -> OT | Historian collects process data |

Everything else is denied by default. In particular:

| Path | Verdict | Reason |
|------|---------|--------|
| IT -> OT (any) | DENY + LOG | No business need; the #1 OT attack path |
| OT -> IT / DMZ (new connections) | DENY + LOG | Process network must not initiate outbound |
| DMZ -> OT, any port other than 502, any host other than the PLC | DENY | Least privilege |
| DMZ -> IT | DENY | DMZ is a data broker, not a pivot point |

## Known limitation (deliberately discussed in the README)
A port-based firewall can't tell a Modbus **read** (FC3) from a **write** (FC6) - both are TCP 502.
Conduit C2 therefore still permits a compromised historian to write to the PLC.
That residual risk is what Project 02 (OT visibility & detection) addresses.
