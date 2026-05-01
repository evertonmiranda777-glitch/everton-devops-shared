#!/usr/bin/env bash
# vercel-revert.sh — promove deploy READY anterior pra prod via API Vercel.
# Requires: VERCEL_TOKEN, VERCEL_PROJECT_ID
# Outputs: PREV_DEPLOY_URL na stdout (pra usar em alertas)

set -euo pipefail

: "${VERCEL_TOKEN:?VERCEL_TOKEN required}"
: "${VERCEL_PROJECT_ID:?VERCEL_PROJECT_ID required}"

API="https://api.vercel.com"
HDR="Authorization: Bearer $VERCEL_TOKEN"

echo "Fetching last 3 prod deployments..." >&2
DEPLOYS=$(curl -sS -H "$HDR" \
  "$API/v6/deployments?projectId=$VERCEL_PROJECT_ID&target=production&limit=3&state=READY")

# Pega o segundo (deployments[1]) — primeiro é o atual quebrado
PREV_ID=$(echo "$DEPLOYS" | jq -r '.deployments[1].uid // empty')
PREV_URL=$(echo "$DEPLOYS" | jq -r '.deployments[1].url // empty')

if [[ -z "$PREV_ID" || -z "$PREV_URL" ]]; then
  echo "ERROR: no previous READY deployment found" >&2
  exit 1
fi

echo "Promoting $PREV_ID ($PREV_URL) to prod..." >&2
RESULT=$(curl -sS -X POST -H "$HDR" \
  "$API/v10/projects/$VERCEL_PROJECT_ID/promote/$PREV_ID")

if echo "$RESULT" | jq -e '.error' >/dev/null 2>&1; then
  echo "ERROR: promote failed:" >&2
  echo "$RESULT" >&2
  exit 1
fi

echo "$PREV_URL"
