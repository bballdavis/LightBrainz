FROM metabrainz/musicbrainz-server:latest

# Install minimal build/runtime helpers needed by downstream service images.
# Be resilient: try apt-get (Debian/Ubuntu), fall back to apk (Alpine), or
# skip if neither package manager is available (useful on constrained hosts).
RUN set -eux; \
  if command -v apt-get >/dev/null 2>&1; then \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates bash coreutils python3 python3-pip curl git cron tini && rm -rf /var/lib/apt/lists/*; \
  elif command -v apk >/dev/null 2>&1; then \
    apk add --no-cache ca-certificates bash coreutils python3 py3-pip curl git busybox-suid tini; \
  else \
    echo "No supported package manager (apt-get/apk) found; proceeding without installing system packages"; \
  fi; \
  if command -v python3 >/dev/null 2>&1; then \
    python3 -m pip install --no-cache-dir sir || true; \
  fi

WORKDIR /app

CMD ["/bin/sh", "-c", "sleep infinity"]
