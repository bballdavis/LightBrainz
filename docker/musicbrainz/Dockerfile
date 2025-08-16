ARG BASE_IMAGE=metabrainz/musicbrainz-server:latest
# The base image for MusicBrainz is provided via the `BASE_IMAGE` build arg.
# The `setup.sh` helper will attempt to build the official upstream
# `musicbrainz-docker` sources (from a tarball) and tag the result as the
# configured base image when the image is not present locally. Override
# `BASE_IMAGE` at build-time to point at a different image/tag if needed.
FROM ${BASE_IMAGE}
# TODO: Add custom config mounts/init as needed
