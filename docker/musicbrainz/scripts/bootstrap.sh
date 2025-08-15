#!/usr/bin/env bash
set -euo pipefail

host="${MB_DB_HOST:-musicbrainz-db}"
port="${MB_DB_PORT:-5432}"
db="${MB_DB_NAME:-musicbrainz}"
user="${MB_DB_USER:-musicbrainz}"
pass="${MB_DB_PASSWORD:-musicbrainz}"
sslmode="${MB_DB_SSLMODE:-disable}"

export PGPASSWORD="$pass"

# Wait for DB
until psql -h "$host" -p "$port" -U "$user" -d "$db" -c "select 1" >/dev/null 2>&1; do
  echo "[mb-bootstrap] Waiting for database..."
  sleep 2
Done

echo "[mb-bootstrap] Checking for existing schema..."
if psql -h "$host" -p "$port" -U "$user" -d "$db" -Atc "select to_regclass('artist') is not null;" | grep -qi t; then
  echo "[mb-bootstrap] Schema detected; skipping import."
  exit 0
fi

echo "[mb-bootstrap] No schema detected."
if [[ "${MB_IMPORT_DUMPS:-true}" == "true" && -n "${MB_DUMPS_URL:-}" ]]; then
  echo "[mb-bootstrap] Importing dump from $MB_DUMPS_URL ..."
  # Supports .sql, .sql.gz; autodetect by extension
  case "$MB_DUMPS_URL" in
    *.sql.gz)
      curl -fsSL "$MB_DUMPS_URL" | gunzip -c | psql -h "$host" -p "$port" -U "$user" -d "$db" ;;
    *.sql)
      curl -fsSL "$MB_DUMPS_URL" | psql -h "$host" -p "$port" -U "$user" -d "$db" ;;
    *)
      echo "[mb-bootstrap] Unsupported dump format. Provide a .sql or .sql.gz URL." ;;
  esac
  echo "[mb-bootstrap] Import complete."
else
  echo "[mb-bootstrap] Skipping dump import. Set MB_IMPORT_DUMPS=true and MB_DUMPS_URL to enable."
fi
