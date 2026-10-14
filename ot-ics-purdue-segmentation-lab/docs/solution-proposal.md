# Solution Proposal: IT/OT Network Segmentation for a Water-Treatment Pumping Station
*Customer-facing format. Fictional customer "Rivermont Water Authority"; the lab is the proof-of-concept.*

## 1. Executive summary
Rivermont's corporate network can currently reach the pump-station PLCs. A single compromised
laptop could therefore stop water supply. We propose a Purdue-model segmentation with an
industrial DMZ so that business users get process data **without any direct path to the controllers**.

## 2. Current state (assumed)
Flat network, shared switch, no firewall between office PCs and PLCs, vendor remote access via
a shared desktop session.

## 3. Proposed architecture
* Three zones (IT / DMZ / OT) separated by a stateful firewall; two documented conduits (C1, C2).
* Historian in the DMZ is the only system that talks to the PLC; IT only talks to the historian.
* Default-deny, every denial logged to feed monitoring (see Project 02).
See `zone-conduit-matrix.md` and the diagram in the main README.

## 4. Why this design
| Requirement | How the design meets it |
|-------------|-------------------------|
| Business wants live process data | Historian web API in DMZ (C1) |
| Controllers must not be reachable from IT | No IT->OT rule; verified by tests T02, T03, T12 |
| Auditability | Zone/conduit matrix + firewall logs + automated test report |
| Standards alignment | IEC 62443-3-2 zones/conduits; IEC 62443-3-3 SR 5.1 / 5.2 |

## 5. Validation results
Automated suite `tests/run_tests.sh` (12 tests). Attach the generated `tests/results/*.md` file here.

## 6. Residual risks & recommendations
1. Port-based filtering cannot distinguish Modbus reads from writes -> add passive OT monitoring (Project 02).
2. Modbus/TCP has no authentication -> restrict to named hosts (done) and monitor for new talkers.
3. Remote vendor access still needed -> jump host in DMZ with MFA and session recording (phase 2).

## 7. Phased rollout
| Phase | Scope | Outcome |
|-------|-------|---------|
| 0 | Asset inventory, traffic baseline | Know what talks to what |
| 1 | Deploy firewall in monitor-only mode | Validate conduits without outage |
| 2 | Enforce default-deny | Segmentation live |
| 3 | Add OT IDS + secure remote access | Detection and controlled vendor access |
