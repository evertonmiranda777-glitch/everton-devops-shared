#!/usr/bin/env bash
# health-check.sh — valida URLs (status 200 + grep content). Roda 3x com 30s gap.
# Usage: HEALTH_URLS="url1|content1\nurl2|content2" ./health-check.sh
# Exit 0 = healthy, 1 = down

set -uo pipefail

ATTEMPTS=${HEALTH_ATTEMPTS:-3}
SLEEP=${HEALTH_SLEEP:-30}
TIMEOUT=${HEALTH_TIMEOUT:-15}

check_once() {
  local fail=0
  while IFS='|' read -r url expect; do
    [[ -z "$url" ]] && continue
    local resp http body
    resp=$(curl -sS --max-time "$TIMEOUT" "$url" -w "\n__HTTP_CODE__%{http_code}" 2>/dev/null) || { echo "  ✗ $url — curl failed"; fail=$((fail+1)); continue; }
    http=$(echo "$resp" | tail -n1 | sed 's/__HTTP_CODE__//')
    body=$(echo "$resp" | sed '$d')
    if [[ "$http" != "200" ]]; then
      echo "  ✗ $url — HTTP $http"
      fail=$((fail+1))
    elif [[ -n "$expect" ]] && ! echo "$body" | grep -qF "$expect"; then
      echo "  ✗ $url — content '$expect' not found"
      fail=$((fail+1))
    else
      echo "  ✓ $url"
    fi
  done <<< "${HEALTH_URLS:-}"
  return $fail
}

for attempt in $(seq 1 "$ATTEMPTS"); do
  echo "Attempt $attempt/$ATTEMPTS"
  if check_once; then
    echo "All URLs healthy on attempt $attempt"
    exit 0
  fi
  if [[ "$attempt" -lt "$ATTEMPTS" ]]; then
    echo "Waiting ${SLEEP}s before retry..."
    sleep "$SLEEP"
  fi
done

echo "All $ATTEMPTS attempts failed — site is DOWN"
exit 1
