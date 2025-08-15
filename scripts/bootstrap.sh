#!/usr/bin/env bash
set -euo pipefail

mkdir -p ./volumes/musicbrainz-db ./volumes/musicbrainz-search ./volumes/musicbrainz-redis ./volumes/hearring-aid-data
[ -f .env ] || cp .env.example .env

echo "Bootstrap complete. Review .env and docker-compose.yml."
