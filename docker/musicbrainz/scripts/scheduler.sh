#!/usr/bin/env bash
set -euo pipefail

interval_from_freq() {
  case "${1:-weekly}" in
    daily) echo 86400;;
    weekly) echo 604800;;
    monthly) echo 2592000;;
    *) echo 604800;;
  esac
}

ID="${SERVICE_ID:-mb-replicator}"
FREQ="${REPLICATION_FREQUENCY:-${INDEX_FREQUENCY:-weekly}}"
INTERVAL="$(interval_from_freq "$FREQ")"
STATE_DIR="/state"
STATE_FILE="${STATE_DIR}/${ID}.last"
RUN_CMD="${RUN_CMD:-/scripts/replicate.sh}"

mkdir -p "$STATE_DIR"

while true; do
  NOW=$(date +%s)
  LAST=0
  if [[ -f "$STATE_FILE" ]]; then
    LAST=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
  fi
  NEXT=$((LAST + INTERVAL))
  if [[ "$NOW" -lt "$NEXT" ]]; then
    SLEEP_FOR=$((NEXT - NOW))
    echo "[${ID}] Sleeping ${SLEEP_FOR}s until next run (freq=$FREQ)"
    sleep "$SLEEP_FOR"
  fi
  echo "[${ID}] Running scheduled task..."
  if ! bash -c "$RUN_CMD"; then
    echo "[${ID}] Task failed (non-fatal). Will retry on next window." >&2
  fi
  date +%s > "$STATE_FILE"
  echo "[${ID}] Done. Sleeping ${INTERVAL}s"
  sleep "$INTERVAL"
done
