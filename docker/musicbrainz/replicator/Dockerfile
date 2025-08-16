ARG BASE_IMAGE=metabrainz/musicbrainz-server:latest
# See README in repo and setup.sh: the `setup.sh` helper prefers building the
# upstream `musicbrainz-docker` tarball and tagging it as the `BASE_IMAGE`.
# You can override this build arg to point at a different base image if
# required.
FROM ${BASE_IMAGE}
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates bash coreutils && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY ../scripts/ /scripts/
RUN chmod +x /scripts/*.sh
ENTRYPOINT ["/bin/bash", "-lc", "/scripts/scheduler.sh"]
