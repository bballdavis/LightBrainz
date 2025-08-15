#!/usr/bin/env bash
set -euo pipefail

host="${MB_DB_HOST:-musicbrainz-db}"
port="${MB_DB_PORT:-5432}"
db="${MB_DB_NAME:-musicbrainz}"
user="${MB_DB_USER:-musicbrainz}"
pass="${MB_DB_PASSWORD:-musicbrainz}"
sslmode="${MB_DB_SSLMODE:-disable}"

export PGPASSWORD="$pass"

# Skip if DB not initialized (artist table absent)
if ! psql -h "$host" -p "$port" -U "$user" -d "$db" -Atc "select to_regclass('artist') is not null;" | grep -qi t; then
	echo "[mb-replicator] DB not initialized yet. Skipping replication cycle."
	exit 0
fi

if [[ -z "${MB_REPLICATION_ACCESS_TOKEN:-}" ]]; then
	echo "[mb-replicator] Missing MB_REPLICATION_ACCESS_TOKEN; cannot replicate."
	exit 0
fi

echo "[mb-replicator] (placeholder) Apply replication packets of type ${MB_REPLICATION_TYPE:-hourly}"
# TODO: Implement replication per official musicbrainz-docker instructions using the token.
