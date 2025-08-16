ARG BASE_IMAGE=metabrainz/musicbrainz-server:latest
# Build-time note: the base image is expected to be available locally. The
# `setup.sh` helper will attempt to build the upstream `musicbrainz-docker`
# tarball and tag it as the `BASE_IMAGE` when necessary.
FROM ${BASE_IMAGE}

WORKDIR /app
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/scripts/bootstrap.sh"]
