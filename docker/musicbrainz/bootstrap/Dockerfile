FROM metabrainz/musicbrainz-server:latest

WORKDIR /app
COPY ../scripts/ /scripts/
RUN chmod +x /scripts/*.sh

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/scripts/bootstrap.sh"]
