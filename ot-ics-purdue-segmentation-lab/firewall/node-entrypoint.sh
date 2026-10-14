#!/usr/bin/env bash
# Generic node entrypoint: add static routes to the other zones via the firewall
# (ROUTES="10.10.20.0/24 10.10.30.0/24", GATEWAY=10.10.10.254), then exec the app.
set -e
if [[ -n "${GATEWAY:-}" && -n "${ROUTES:-}" ]]; then
  for r in $ROUTES; do ip route replace "$r" via "$GATEWAY"; done
  echo "[node] routes: $(ip route | tr '\n' ';')"
fi
exec "$@"
