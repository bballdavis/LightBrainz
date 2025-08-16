#!/usr/bin/env bash
set -euo pipefail

# One-shot setup (Linux/macOS)
# 1) Prepare env/volumes
# 2) Start db/redis/search and wait for db healthy
# 3) Run mb-bootstrap (createdb.sh -fetch)
# 4) Start remaining services
# 5) If token set, run one replication cycle
# 6) Smoke-check web

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

[[ -f .env || ! -f .env.example ]] || cp .env.example .env

mkdir -p volumes/musicbrainz-db \
         volumes/musicbrainz-search \
         volumes/musicbrainz-redis \
         volumes/hearring-aid-data \
         volumes/state

wait_healthy() {
  local svc="$1"; local timeout="${2:-900}"; local start now status cid
  start="$(date +%s)"
  cid="$(docker compose ps -q "$svc" | tr -d '\r')"
  [[ -n "$cid" ]] || { echo "Service $svc not running"; return 1; }
  while true; do
    status="$(docker inspect -f '{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "")"
    [[ "$status" == "healthy" ]] && return 0
    now="$(date +%s)"
    if (( now - start > timeout )); then
      echo "Timed out waiting for $svc to be healthy (last status=$status)"
      return 1
    fi
    sleep 2
  done
}

env_val() { grep -E "^$1=" .env 2>/dev/null | head -n1 | cut -d= -f2-; }

echo "Starting core services: musicbrainz-db, redis, search..."
docker compose up -d musicbrainz-db redis search

echo "Waiting for database to be healthy..."
wait_healthy musicbrainz-db || echo "Warning: db health not reported healthy; continuing"

echo "Running bootstrap (dumps import)..."
if ! docker compose run --build --rm mb-bootstrap; then
  echo "[setup] Bootstrap failed; replication may catch up."
fi

echo "Starting services: musicbrainz, mb-replicator, mb-indexer, hearring-aid..."
docker compose up -d musicbrainz mb-replicator mb-indexer hearring-aid

token="$(env_val MB_REPLICATION_ACCESS_TOKEN || true)"
if [[ -n "${token:-}" ]]; then
  echo "Triggering one replication cycle..."
  if ! docker compose exec -T mb-replicator bash -lc '/scripts/replicate.sh'; then
    echo "[setup] One-shot replication failed; scheduled job will retry."
  fi
else
  echo "No replication token set; skipping immediate replication."
fi

MB_PORT="$(env_val MB_WEB_PORT || true)"; MB_PORT="${MB_PORT:-5800}"
echo "Checking MusicBrainz web at http://localhost:${MB_PORT} ..."
ok=0
for i in {1..60}; do
  if curl -fsS -m 5 "http://localhost:${MB_PORT}" >/dev/null; then ok=1; break; fi
  sleep 2
done || true
if [[ "$ok" == "1" ]]; then
  echo "MusicBrainz web is responding."
else
  echo "MusicBrainz web did not respond yet; containers may still be warming up."
fi

echo "One-shot setup complete. MusicBrainz: http://localhost:${MB_PORT}"
