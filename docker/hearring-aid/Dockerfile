FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git bash cron tini \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY docker/hearring-aid/scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

ENV MB_DB_HOST=musicbrainz-db \
    MB_DB_PORT=5432 \
    MB_DB_NAME=musicbrainz \
    MB_DB_USER=musicbrainz \
    MB_DB_PASS=musicbrainz \
    MB_DB_SSLMODE=disable \
    OUTPUT_DIR=/data \
    HA_CRON_SCHEDULE=daily

VOLUME ["/data"]

ENTRYPOINT ["/usr/bin/tini", "--", "/app/scripts/entrypoint.sh"]
