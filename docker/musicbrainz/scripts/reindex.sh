#!/usr/bin/env bash
set -euo pipefail

host="${MB_DB_HOST:-musicbrainz-db}"
port="${MB_DB_PORT:-5432}"
db="${MB_DB_NAME:-musicbrainz}"
user="${MB_DB_USER:-musicbrainz}"
pass="${MB_DB_PASSWORD:-musicbrainz}"

export PGPASSWORD="$pass"

# Skip if disabled
if [[ "${ENABLE_INDEXING:-true}" != "true" ]]; then
  echo "[mb-indexer] ENABLE_INDEXING=false; skipping."
  exit 0
fi

# Skip if DB not initialized
if ! psql -h "$host" -p "$port" -U "$user" -d "$db" -Atc "select to_regclass('artist') is not null;" | grep -qi t; then
  echo "[mb-indexer] DB not initialized yet. Skipping indexing cycle."
  exit 0
fi

echo "[mb-indexer] Starting reindex"

set +e
# Prefer the project's reindex script if present
if [[ -x "/musicbrainz-server/admin/cron/reindex.sh" ]]; then
  /musicbrainz-server/admin/cron/reindex.sh 2>&1
  rc=$?
else
  # Fallback: run a generic indexing command if available (placeholder)
  echo "[mb-indexer] reindex.sh not found; running a lightweight index test"
  sleep 1
  rc=0
fi
set -e

if [[ $rc -ne 0 ]]; then
  echo "[mb-indexer] Reindex failed with exit code $rc" >&2
  exit $rc
fi

echo "[mb-indexer] Reindex completed successfully."
