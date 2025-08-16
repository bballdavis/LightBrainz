ARG BASE_IMAGE=metabrainz/musicbrainz-server:latest
# The base musicbrainz server image is typically built from the upstream
# sources by `setup.sh`. Override `BASE_IMAGE` when building if you need a
# different base image.
FROM ${BASE_IMAGE}
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates bash coreutils python3 python3-pip && rm -rf /var/lib/apt/lists/*
RUN python3 -m pip install --no-cache-dir sir
WORKDIR /app
COPY ../scripts/ /scripts/
RUN chmod +x /scripts/*.sh
ENTRYPOINT ["/bin/bash", "-lc", "/scripts/scheduler.sh"]
