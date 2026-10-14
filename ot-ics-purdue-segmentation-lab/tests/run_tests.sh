#!/usr/bin/env bash
# Segmentation verification suite. Proves the firewall enforces the zone/conduit matrix.
# Each probe is classified from the client's point of view:
#   OPEN      TCP handshake completed        (service reachable)
#   REFUSED   RST received                   (host reachable, port closed)  -> path exists!
#   FILTERED  timeout, no answer             (packets silently dropped)     -> path blocked
# PASS rules:  ALLOW tests must be OPEN;  DENY tests must be FILTERED.
set -u
cd "$(dirname "$0")"
OUT="results/results-$(date +%Y%m%d-%H%M%S).md"
PASS=0; FAIL=0

probe() {   # probe <from-container> <ip> <port>
  docker exec "$1" timeout 4 bash -c "exec 3<>/dev/tcp/$2/$3" >/dev/null 2>&1
  case $? in 0) echo OPEN;; 124) echo FILTERED;; *) echo REFUSED;; esac
}

{ echo "# Segmentation test results"; echo; echo "Run: $(date -u +'%F %T UTC')"; echo
  echo "| ID | Test | Expected | Observed | Result |"
  echo "|----|------|----------|----------|--------|"; } > "$OUT"

check() {   # check <id> <desc> <from> <ip> <port> <ALLOW|DENY>
  local id=$1 desc=$2 from=$3 ip=$4 port=$5 want=$6 got exp res
  got=$(probe "$from" "$ip" "$port")
  [[ $want == ALLOW ]] && exp=OPEN || exp=FILTERED
  if [[ $got == "$exp" ]]; then res="PASS"; PASS=$((PASS+1)); else res="**FAIL**"; FAIL=$((FAIL+1)); fi
  echo "| $id | $desc | $want ($exp) | $got | $res |" | tee -a "$OUT"
}

echo "== Running segmentation tests =="
check T01 "IT workstation -> Historian web (8081)"        it-ws     10.10.20.10 8081 ALLOW
check T02 "IT workstation -> PLC Modbus (502) [DIRECT]"   it-ws     10.10.30.10 502  DENY
check T03 "IT workstation -> HMI (502)"                   it-ws     10.10.30.20 502  DENY
check T04 "IT workstation -> Historian SSH (22)"          it-ws     10.10.20.10 22   DENY
check T05 "Historian -> PLC Modbus (502)"                 historian 10.10.30.10 502  ALLOW
check T06 "Historian -> PLC HTTP (80)"                    historian 10.10.30.10 80   DENY
check T07 "Historian -> HMI (502)"                        historian 10.10.30.20 502  DENY
check T08 "Historian -> IT workstation (22)"              historian 10.10.10.10 22   DENY
check T09 "PLC -> IT workstation (22) [OT outbound]"      plc       10.10.10.10 22   DENY
check T10 "PLC -> Historian web (8081) [OT outbound]"     plc       10.10.20.10 8081 DENY

# Functional proof: the allowed business flow really works end-to-end
if docker exec it-ws curl -s -m 5 http://10.10.20.10:8081 | grep -q '"status": "ok"'; then
  echo "| T11 | IT user reads process data via historian | ALLOW | data returned | PASS |" | tee -a "$OUT"; PASS=$((PASS+1))
else
  echo "| T11 | IT user reads process data via historian | ALLOW | no data | **FAIL** |" | tee -a "$OUT"; FAIL=$((FAIL+1))
fi

# ICMP should not cross IT -> OT either
if docker exec it-ws ping -c1 -W2 10.10.30.10 >/dev/null 2>&1; then
  echo "| T12 | ICMP IT -> PLC | DENY | reply received | **FAIL** |" | tee -a "$OUT"; FAIL=$((FAIL+1))
else
  echo "| T12 | ICMP IT -> PLC | DENY | no reply | PASS |" | tee -a "$OUT"; PASS=$((PASS+1))
fi

{ echo; echo "**Summary: $PASS passed, $FAIL failed**"; echo
  echo "## Firewall evidence (FORWARD chain hit counters)"; echo '```'
  docker exec firewall iptables -L FORWARD -v -n --line-numbers; echo '```'; } >> "$OUT"
echo; echo "Summary: $PASS passed, $FAIL failed  ->  $OUT"
[[ $FAIL -eq 0 ]]
