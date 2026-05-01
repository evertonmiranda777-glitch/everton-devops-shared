#!/usr/bin/env bash
# notify-telegram.sh — alerta via Telegram bot.
# Requires: TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
# Usage: ./notify-telegram.sh "mensagem aqui"

set -euo pipefail

: "${TELEGRAM_BOT_TOKEN:?required}"
: "${TELEGRAM_CHAT_ID:?required}"

MSG="${1:-(empty message)}"

curl -sS -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
  --data-urlencode "text=$MSG" \
  --data-urlencode "parse_mode=HTML" \
  --data-urlencode "disable_web_page_preview=true" \
  >/dev/null
