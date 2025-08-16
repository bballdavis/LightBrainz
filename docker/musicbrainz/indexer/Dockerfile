FROM metabrainz/musicbrainz-server:latest
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates bash coreutils python3 python3-pip && rm -rf /var/lib/apt/lists/*
RUN python3 -m pip install --no-cache-dir sir
WORKDIR /app
COPY ../scripts/ /scripts/
RUN chmod +x /scripts/*.sh
ENTRYPOINT ["/bin/bash", "-lc", "/scripts/scheduler.sh"]
