ARG BASE_IMAGE=metabrainz/musicbrainz-server:latest
# Base image may be overridden by setup.sh to point at a local builder image
FROM ${BASE_IMAGE}
RUN python3 -m pip install --no-cache-dir sir || true
WORKDIR /app
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh
ENTRYPOINT ["/bin/bash", "-lc", "/scripts/scheduler.sh"]
