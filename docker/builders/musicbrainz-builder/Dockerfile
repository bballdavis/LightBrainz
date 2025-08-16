FROM metabrainz/musicbrainz-server:latest

# Install minimal build/runtime helpers needed by downstream service images.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates bash coreutils python3 python3-pip curl git cron tini \
  && python3 -m pip install --no-cache-dir sir \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["/bin/sh", "-c", "sleep infinity"]
