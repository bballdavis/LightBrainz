ARG BASE_IMAGE=python:3.11-slim
FROM ${BASE_IMAGE}

# Install shells/helpers via the builder image when possible; keep this
# Dockerfile minimal so builds can use a prebuilt builder image instead of
# running apt on constrained hosts.
WORKDIR /app
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh || true

ENV MB_DB_HOST=musicbrainz-db \
  MB_DB_PORT=5432 \
  MB_DB_NAME=musicbrainz \
  MB_DB_USER=musicbrainz \
  MB_DB_PASS=musicbrainz \
  MB_DB_SSLMODE=disable \
  OUTPUT_DIR=/data \
  HA_CRON_SCHEDULE=daily

VOLUME ["/data"]

ENTRYPOINT ["/bin/sh", "-c", "/app/scripts/entrypoint.sh"]
