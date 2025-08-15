#!/usr/bin/env bash
set -euo pipefail

# LightBrainz setup (Linux/macOS)
# - Copies .env.example to .env if missing
# - Ensures data folders exist
# - Brings the stack up via docker compose

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f .env && -f .env.example ]]; then
  cp .env.example .env
fi

mkdir -p volumes/musicbrainz-db \
         volumes/musicbrainz-search \
         volumes/musicbrainz-redis \
         volumes/hearring-aid-data

docker compose up -d

MB_PORT="$(grep -E '^MB_WEB_PORT=' .env 2>/dev/null | head -n1 | cut -d= -f2 || true)"
MB_PORT="${MB_PORT:-5800}"
echo "Deployment started. MusicBrainz: http://localhost:${MB_PORT}"
