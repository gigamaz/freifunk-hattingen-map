#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/marcus/ffmap/docker"
DATA_DIR="$BASE_DIR/data"
ENV_FILE="$BASE_DIR/healthcheck.env"
STATE_FILE="$DATA_DIR/healthcheck_state"
NODES_JSON="$DATA_DIR/nodes.json"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
NOW="$(date '+%Y-%m-%d %H:%M:%S %Z')"

FAIL_THRESHOLD="${FAIL_THRESHOLD:-1}"
ALERT_EMAIL_TO="${ALERT_EMAIL_TO:-}"
ALERT_EMAIL_FROM="${ALERT_EMAIL_FROM:-ffcollector-monitor@localhost}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

bat_active=0
if batctl if 2>/dev/null | grep -q '^l2tp-hat: active'; then
  bat_active=1
fi

neighbors=0
neighbors="$(batctl n 2>/dev/null | awk 'NR>2 {c++} END {print c+0}')"

online=0
total=0
if [[ -f "$NODES_JSON" ]]; then
  counts="$(python3 - <<'PY'
import json
from pathlib import Path
p=Path('/home/marcus/ffmap/docker/data/nodes.json')
try:
    d=json.loads(p.read_text())
    nodes=d.get('nodes', [])
    total=len(nodes)
    online=sum(1 for n in nodes if n.get('flags', {}).get('online'))
    print(f"{online} {total}")
except Exception:
    print('0 0')
PY
)"
  online="$(awk '{print $1}' <<<"$counts")"
  total="$(awk '{print $2}' <<<"$counts")"
fi

status="OK"
reason="online=$online/$total neighbors=$neighbors l2tp-hat=$( [[ "$bat_active" -eq 1 ]] && printf active || printf inactive )"

if [[ "$bat_active" -ne 1 || "$neighbors" -le 0 || "$online" -le 0 ]]; then
  status="BAD"
fi

last_status="OK"
fail_count=0
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

if [[ "$status" == "BAD" ]]; then
  fail_count=$((fail_count + 1))
else
  fail_count=0
fi

send_alert=0
send_recovery=0
if [[ "$status" == "BAD" && "$fail_count" -ge "$FAIL_THRESHOLD" && "$last_status" != "BAD" ]]; then
  send_alert=1
fi
if [[ "$status" == "OK" && "$last_status" == "BAD" ]]; then
  send_recovery=1
fi

msg_alert="FFCOLLECTOR ALERT: Yanic sammelt keine oder zu wenige Daten auf $HOSTNAME_SHORT (${HOST_IP:-unknown}) um $NOW. $reason"
msg_ok="FFCOLLECTOR OK: Mesh wiederhergestellt auf $HOSTNAME_SHORT (${HOST_IP:-unknown}) um $NOW. $reason"

send_telegram() {
  local text="$1"
  [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]] || return 0
  curl --silent --show-error --fail \
    -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${text}" >/dev/null
}

send_mail() {
  local subject="$1"
  local text="$2"
  [[ -n "$ALERT_EMAIL_TO" ]] || return 0
  if command -v mail >/dev/null 2>&1; then
    printf '%s\n' "$text" | mail -s "$subject" -r "$ALERT_EMAIL_FROM" "$ALERT_EMAIL_TO"
  elif command -v mailx >/dev/null 2>&1; then
    printf '%s\n' "$text" | mailx -s "$subject" -r "$ALERT_EMAIL_FROM" "$ALERT_EMAIL_TO"
  else
    logger -t ffcollector-healthcheck "Mail nicht gesendet (mail/mailx fehlt): $subject | $text"
  fi
}

if [[ "$send_alert" -eq 1 ]]; then
  send_telegram "$msg_alert" || true
  send_mail "FFCOLLECTOR ALERT" "$msg_alert" || true
  logger -t ffcollector-healthcheck "$msg_alert"
fi

if [[ "$send_recovery" -eq 1 ]]; then
  send_telegram "$msg_ok" || true
  send_mail "FFCOLLECTOR OK" "$msg_ok" || true
  logger -t ffcollector-healthcheck "$msg_ok"
fi

cat > "$STATE_FILE" <<EOF
last_status="$status"
fail_count="$fail_count"
EOF
