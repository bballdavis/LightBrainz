FROM metabrainz/musicbrainz-server:latest
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates bash coreutils && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY ../scripts/ /scripts/
RUN chmod +x /scripts/*.sh
ENTRYPOINT ["/bin/bash", "-lc", "/scripts/scheduler.sh"]
