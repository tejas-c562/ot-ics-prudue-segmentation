#!/usr/bin/env bash
# Zone firewall for the Purdue-model lab (Level 3.5 industrial DMZ boundary).
# Policy: default-deny FORWARD, then explicitly allow the minimum conduits.
# Rules match on SUBNETS (not interface names) because Docker assigns eth0..ethN
# in a non-guaranteed order.
set -euo pipefail

IT=10.10.10.0/24
DMZ=10.10.20.0/24
OT=10.10.30.0/24

HISTORIAN=10.10.20.10
PLC=${PLC_IP:-10.10.30.10}

echo "[fw] flushing and applying default-deny policy"
iptables -F
iptables -t nat -F
iptables -X || true
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT

# The firewall itself: allow loopback + replies
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT   # lab troubleshooting only

# --- Stateful baseline: return traffic for permitted sessions -----------------
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP

# --- CONDUIT C1: IT -> DMZ  (historian web UI only) --------------------------
iptables -A FORWARD -s $IT -d $HISTORIAN -p tcp --dport 8081 \
         -m conntrack --ctstate NEW -j ACCEPT

# --- CONDUIT C2: DMZ -> OT  (historian polls the PLC over Modbus/TCP only) ----
iptables -A FORWARD -s $HISTORIAN -d $PLC -p tcp --dport 502 \
         -m conntrack --ctstate NEW -j ACCEPT

# --- Explicit, logged denials for the paths that must NEVER exist ------------
# IT -> OT direct (the classic flat-network failure)
iptables -A FORWARD -s $IT  -d $OT -m limit --limit 5/min \
         -j LOG --log-prefix "FW-DENY IT->OT: " --log-level 4
iptables -A FORWARD -s $IT  -d $OT -j DROP
# OT -> IT/DMZ initiated connections (no outbound from the process network)
iptables -A FORWARD -s $OT  -m conntrack --ctstate NEW -m limit --limit 5/min \
         -j LOG --log-prefix "FW-DENY OT-out: " --log-level 4
iptables -A FORWARD -s $OT  -m conntrack --ctstate NEW -j DROP
# Everything else (DMZ->OT other ports, DMZ->IT, ...) hits the default DROP,
# but log it so the test report can show evidence.
iptables -A FORWARD -m limit --limit 5/min \
         -j LOG --log-prefix "FW-DENY default: " --log-level 4

# Optional: NAT toward OT for third-party nodes (e.g. real OpenPLC) that cannot
# be given a static route back through this firewall. Costs source-IP visibility.
if [[ "${NAT_TO_OT:-0}" == "1" ]]; then
  echo "[fw] NAT_TO_OT=1 -> masquerading traffic destined to OT"
  iptables -t nat -A POSTROUTING -d $OT -j MASQUERADE
fi

echo "[fw] ruleset active:"
iptables -S FORWARD
exec sleep infinity
