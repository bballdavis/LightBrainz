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
    printf "%s [%s] Sleeping %ss until next run (freq=%s)\n" "$(date --rfc-3339=seconds 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')" "$ID" "$SLEEP_FOR" "$FREQ"
    sleep "$SLEEP_FOR"
  fi
  printf "%s [%s] Running scheduled task...\n" "$(date --rfc-3339=seconds 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')" "$ID"
  # Run the task and stream both stdout and stderr with a prefix so Docker logs capture them
  bash -c "$RUN_CMD" 2>&1 | sed -u "s/^/[$ID] /" || printf "%s [%s] Task failed (non-fatal). Will retry on next window.\n" "$(date --rfc-3339=seconds 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')" "$ID" >&2
  date +%s > "$STATE_FILE"
  printf "%s [%s] Done. Sleeping %ss\n" "$(date --rfc-3339=seconds 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')" "$ID" "$INTERVAL"
  sleep "$INTERVAL"
done
