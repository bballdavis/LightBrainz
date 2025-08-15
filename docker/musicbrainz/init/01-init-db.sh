#!/usr/bin/env bash
set -euo pipefail

# Wait for DB
until pg_isready -h musicbrainz-db -p 5432 -U ${MB_DB_USER:-musicbrainz}; do
  echo "Waiting for database to be ready..."
  sleep 2
done

echo "Database ready."
