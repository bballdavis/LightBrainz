FROM alpine:3.19

RUN apk add --no-cache bash curl ca-certificates postgresql15-client coreutils gzip

WORKDIR /app
COPY /docker/musicbrainz/scripts/ /scripts/
RUN chmod +x /scripts/*.sh

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/scripts/bootstrap.sh"]
