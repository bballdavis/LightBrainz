#!/usr/bin/env bash
set -euo pipefail

# Default to a simple sleep-loop scheduler for NAS friendliness (no host cron)
# If HA_CRON_SCHEDULE is a raw cron expression (contains spaces), fall back to cron

SCHEDULE="${HA_CRON_SCHEDULE:-daily}"
case "$SCHEDULE" in
  daily)   SLEEP=86400; USE_CRON=0; CRON_EXPR="0 3 * * *" ;;
  weekly)  SLEEP=604800; USE_CRON=0; CRON_EXPR="0 4 * * 0" ;;
  monthly) SLEEP=2592000; USE_CRON=0; CRON_EXPR="0 5 1 * *" ;;
  "")      SLEEP=0; USE_CRON=0; CRON_EXPR="" ;;
  *" "*)   SLEEP=0; USE_CRON=1; CRON_EXPR="$SCHEDULE" ;;
  *)       SLEEP=86400; USE_CRON=0; CRON_EXPR="0 3 * * *" ;;
esac

if [[ "$USE_CRON" -eq 0 ]]; then
  if [[ "$SLEEP" -eq 0 ]]; then
    echo "[hearring-aid] Running once..."
    exec /app/scripts/generate-metadata.sh
  else
    echo "[hearring-aid] Running in loop every ${SLEEP}s (schedule: $SCHEDULE)"
    while true; do
      /app/scripts/generate-metadata.sh || true
      sleep "$SLEEP"
    done
  fi
else
  echo "[hearring-aid] Scheduling with cron: ${CRON_EXPR}"
  echo "${CRON_EXPR} /app/scripts/generate-metadata.sh >> /var/log/cron.log 2>&1" > /etc/cron.d/hearring-aid
  chmod 0644 /etc/cron.d/hearring-aid
  crontab /etc/cron.d/hearring-aid
  touch /var/log/cron.log
  exec cron -f
fi
