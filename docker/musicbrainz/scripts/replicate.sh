#!/usr/bin/env bash
set -euo pipefail

host="${MB_DB_HOST:-musicbrainz-db}"
port="${MB_DB_PORT:-5432}"
db="${MB_DB_NAME:-musicbrainz}"
user="${MB_DB_USER:-musicbrainz}"
pass="${MB_DB_PASSWORD:-musicbrainz}"
sslmode="${MB_DB_SSLMODE:-disable}"

export PGPASSWORD="$pass"

# Skip if disabled
if [[ "${ENABLE_REPLICATION:-true}" != "true" ]]; then
	echo "[mb-replicator] ENABLE_REPLICATION=false; skipping."
	exit 0
fi

# Skip if DB not initialized (artist table absent)
if ! psql -h "$host" -p "$port" -U "$user" -d "$db" -Atc "select to_regclass('artist') is not null;" | grep -qi t; then
	echo "[mb-replicator] DB not initialized yet. Skipping replication cycle."
	exit 0
fi

# Require token
if [[ -z "${MB_REPLICATION_ACCESS_TOKEN:-}" ]]; then
	echo "[mb-replicator] Missing MB_REPLICATION_ACCESS_TOKEN; cannot replicate."
	exit 0
fi

# Map env for official scripts
export MUSICBRAINZ_POSTGRES_SERVER="$host"
export POSTGRES_USER="$user"
export POSTGRES_PASSWORD="$pass"

# Write token to the expected secrets path
SECRETS_DIR="/run/secrets"
TOKEN_FILE="$SECRETS_DIR/metabrainz_access_token"
mkdir -p "$SECRETS_DIR"
chmod 755 "$SECRETS_DIR"
echo -n "$MB_REPLICATION_ACCESS_TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"
echo "[mb-replicator] Starting replication via mirror.sh (type=${MB_REPLICATION_TYPE:-hourly})"

# Run the official replication script once (as in musicbrainz-docker)
# Use carton to ensure Perl deps/env are applied. Stream all output to stdout
# so Docker captures logs instead of writing to container files.
set +e
carton exec -- /musicbrainz-server/admin/cron/mirror.sh 2>&1
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
	echo "[mb-replicator] Replication failed with exit code $rc" >&2
	exit $rc
fi

echo "[mb-replicator] Replication completed successfully."
