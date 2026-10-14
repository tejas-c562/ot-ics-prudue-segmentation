#!/usr/bin/env bash
# Attacker-view reconnaissance from the IT zone: what can an attacker who owns an
# IT workstation actually see in the OT zone? Expected: everything filtered.
set -u
echo "### From it-ws -> OT zone"
docker exec it-ws nmap -Pn -n -p 22,80,102,502,8080,9090,44818 10.10.30.10 10.10.30.20
echo "### From it-ws -> DMZ"
docker exec it-ws nmap -Pn -n -p 22,80,502,8081 10.10.20.10
