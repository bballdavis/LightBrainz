#!/usr/bin/env bash
# If the user invokes this script with `sh setup.sh` (or another non-bash
# shell), re-exec it under bash so Bash-specific features work as expected.
if [ -z "${BASH_VERSION:-}" ]; then
  if command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  else
    echo "This script requires bash but 'bash' was not found in PATH." >&2
    exit 1
  fi
fi
set -euo pipefail

# One-shot setup (Linux/macOS)
# 1) Prepare env/volumes
# 2) Start db/redis/search and wait for db healthy
# 3) Run mb-bootstrap (createdb.sh -fetch)
# 4) Start remaining services
# 5) If token set, run one replication cycle
# 6) Smoke-check web

# Resolve the script directory robustly. When run via `sh setup.sh` $0 may be
# `sh` and `BASH_SOURCE` may be unavailable; try several fallbacks and ensure
# we end up in the repository root (where docker-compose.yml lives).
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${0:-}" && -f "${0:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
else
  # Fallback to PWD; user may have invoked the script from the repo root using
  # `sh setup.sh` or similar. We'll search upward for a repo marker below.
  SCRIPT_DIR="$PWD"
fi

search_up_for() {
  local start="$1" name="$2" d
  d="$start"
  while [[ -n "$d" && "$d" != "/" ]]; do
    if [[ -e "$d/$name" ]]; then
      printf '%s' "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

# If docker-compose.yml isn't in the resolved dir, try searching upward from
# that directory (and from PWD) for the repo root. This handles being invoked
# from another directory or via `sh setup.sh` which loses the script path.
if [[ ! -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
  found="$(search_up_for "$SCRIPT_DIR" docker-compose.yml || true)"
  if [[ -z "$found" ]]; then
    found="$(search_up_for "$PWD" docker-compose.yml || true)"
  fi
  if [[ -n "$found" ]]; then
    SCRIPT_DIR="$found"
  fi
fi

# If we have a compose file at the SCRIPT_DIR, cd there. Otherwise assume the
# user downloaded only this script into a target directory and wants the full
# repo fetched into the current working directory. Extract the GitHub tarball
# into the current directory and re-exec the extracted `setup.sh`.
if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
  cd "$SCRIPT_DIR" || { echo "Unable to change to repository root $SCRIPT_DIR" >&2; exit 1; }
else
  PARENT_DIR="$PWD"
  BUILD_DIR="$PARENT_DIR/build"
  mkdir -p "$BUILD_DIR"
  echo "[setup] No repository detected in $SCRIPT_DIR; downloading repo into $BUILD_DIR"
  url="https://github.com/bballdavis/LightBrainz/archive/refs/heads/main.tar.gz"
  if ! curl -fsSL "$url" | tar -xzf - --strip-components=1 -C "$BUILD_DIR"; then
    echo "Failed to download or extract repository tarball from $url" >&2
    exit 1
  fi
  echo "[setup] Repository extracted into $BUILD_DIR; running setup from extracted copy"
  # Run the extracted setup with PROJECT_ROOT set in its environment so the
  # extracted script places host volumes under the parent directory (the
  # directory the user intended), not inside the build dir. Use `env` to avoid
  # exec parsing issues on some shells.
  exec env PROJECT_ROOT="$PARENT_DIR" bash "$BUILD_DIR/setup.sh" "$@"
fi

# Debug feedback: show resolved repository root and whether a `.env` file is
# present. This helps debugging when users invoke the script from another
# directory or via `sh`.
echo "[setup] repository root: $SCRIPT_DIR"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  echo "[setup] .env: present at $SCRIPT_DIR/.env"
else
  echo "[setup] .env: NOT found at $SCRIPT_DIR/.env"
fi

# Default PROJECT_ROOT: when the script is running from inside a transient
# build directory (basename == build) we want persistent data to live one
# level up. Otherwise the project root defaults to the script directory.
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  if [[ "$(basename "$SCRIPT_DIR")" == "build" ]]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
  else
    PROJECT_ROOT="$SCRIPT_DIR"
  fi
fi
echo "[setup] project root: $PROJECT_ROOT"

# Require a local `.env` file. When running from an extracted `build/` directory
# prefer the `.env` located in the `build/` (script) directory so users can
# inspect/edit the configuration there before committing it to the project
# root. Otherwise preserve the previous behaviour: require `.env` in
# `PROJECT_ROOT` and, if missing, create it from available examples and exit.
ENV_FILE=""
if [[ "$(basename "$SCRIPT_DIR")" == "build" ]]; then
  # Running from extracted build; prefer .env in the build dir
  if [[ -f "$SCRIPT_DIR/.env" ]]; then
    echo "[setup] using .env from $SCRIPT_DIR/.env"
    ENV_FILE="$SCRIPT_DIR/.env"
  else
    echo "[setup] .env not found in $SCRIPT_DIR; attempting to create from .env.example and exiting so you can edit it."
    if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
      cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
      echo "Created $SCRIPT_DIR/.env from $SCRIPT_DIR/.env.example. Please edit $SCRIPT_DIR/.env and re-run this script."
      exit 0
    fi
  echo "Local .env.example not found in build; attempting to download .env.example from GitHub..."
  url="https://raw.githubusercontent.com/bballdavis/LightBrainz/main/.env.example"
    tmp=$(mktemp)
    if curl -fsSL "$url" -o "$tmp"; then
      if [[ -s "$tmp" ]]; then
        mv "$tmp" "$SCRIPT_DIR/.env"
        echo "Downloaded .env.example -> $SCRIPT_DIR/.env. Please edit it and re-run this script."
        exit 0
      else
        rm -f "$tmp"
        echo "Failed to download a non-empty .env.example from $url" >&2
        exit 1
      fi
    else
      echo "Failed to download .env.example from $url" >&2
      rm -f "$tmp" || true
      exit 1
    fi
  fi
else
  # Normal path: require .env in PROJECT_ROOT
  ENV_FILE="$PROJECT_ROOT/.env"
  if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "[setup] .env not found in $PROJECT_ROOT; attempting to create from .env.example and exiting so you can edit it."
    if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
      cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
      echo "Created $PROJECT_ROOT/.env from $PROJECT_ROOT/.env.example. Please edit $PROJECT_ROOT/.env and re-run this script."
      exit 0
    fi

    if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
      cp "$SCRIPT_DIR/.env.example" "$PROJECT_ROOT/.env"
      echo "Created $PROJECT_ROOT/.env from $SCRIPT_DIR/.env.example. Please edit $PROJECT_ROOT/.env and re-run this script."
      exit 0
    fi

  echo "Local .env.example not found; attempting to download .env.example from GitHub..."
  url="https://raw.githubusercontent.com/bballdavis/LightBrainz/main/.env.example"
    tmp=$(mktemp)
    if curl -fsSL "$url" -o "$tmp"; then
      if [[ -s "$tmp" ]]; then
        mv "$tmp" "$PROJECT_ROOT/.env"
        echo "Downloaded .env.example -> $PROJECT_ROOT/.env. Please edit it and re-run this script."
        exit 0
      else
        rm -f "$tmp"
        echo "Failed to download a non-empty .env.example from $url" >&2
        exit 1
      fi
    else
      echo "Failed to download .env.example from $url" >&2
      rm -f "$tmp" || true
      exit 1
    fi
  fi
fi

# At this point the chosen env file exists. Perform sanity checks and fail
# fast if it looks wrong.
# .env must be non-empty
if [[ ! -s "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE exists but is empty. Replace from .env.example or restore backup." >&2
  exit 1
fi

# Reject files that look like shell scripts accidentally saved as .env
if grep -E -q '(^#!|^set[[:space:]]+-e|BASH_SOURCE|SCRIPT_DIR|function[[:space:]]|\$\{BASH_SOURCE|\$0)' "$ENV_FILE"; then
  echo "ERROR: $ENV_FILE appears to contain shell script content. Please restore a valid .env from .env.example." >&2
  echo "If you intentionally saved .env from a downloaded file, edit it to only contain KEY=VALUE entries." >&2
  exit 1
fi

# Ensure there is at least one KEY=VALUE line
if ! grep -Eq '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE"; then
  echo "ERROR: $ENV_FILE does not contain valid KEY=VALUE lines. Restore .env from .env.example." >&2
  exit 1
fi

# Load variables from the chosen env file into the script environment so
# directory paths defined there are respected by this setup script. We export
# them so any child processes (docker-compose) can also see them where
# appropriate.
set -o allexport
source "$ENV_FILE"
set +o allexport

# Allow forcing rebuilds from environment. Default is false.
FORCE_BUILD="${FORCE_BUILD:-false}"
# Builder image used to provide packages/tools without running apt in service
# Dockerfiles on constrained hosts. Can be overridden in .env
MB_BUILDER_IMAGE="${MB_BUILDER_IMAGE:-lightbrainz/musicbrainz-builder:latest}"

ensure_builder_image() {
  local img="$MB_BUILDER_IMAGE" ctx="$SCRIPT_DIR/docker/builders/musicbrainz-builder"
  if docker image inspect "$img" >/dev/null 2>&1 && [[ "${FORCE_BUILD,,}" != "true" ]]; then
    echo "[setup] builder image $img already present; skipping build"
    return 0
  fi
  if [[ ! -d "$ctx" ]]; then
    echo "[setup] builder context $ctx not found; skipping builder build" >&2
    return 1
  fi
  echo "[setup] building builder image $img from $ctx"
  if docker build -t "$img" "$ctx"; then
    echo "[setup] built builder image $img"
    return 0
  else
    echo "ERROR: failed to build builder image $img" >&2
    return 1
  fi
}

# If the setup intends to import dumps, require a replication access token.
if [[ "${MB_IMPORT_DUMPS:-true}" == "true" && -z "${MB_REPLICATION_ACCESS_TOKEN:-}" ]]; then
  echo "ERROR: MB_IMPORT_DUMPS is enabled but MB_REPLICATION_ACCESS_TOKEN is not set in $ENV_FILE." >&2
  echo "Obtain a replication access token from MetaBrainz and set MB_REPLICATION_ACCESS_TOKEN in $ENV_FILE before re-running." >&2
  exit 1
fi

## Ensure the MusicBrainz base image is available locally by building it from
## the upstream `main` branch tarball. There is no fallback: the image must be
## built from upstream sources (no pull or alternate branches).
BASE_IMAGE_NAME="${MB_BASE_IMAGE:-metabrainz/musicbrainz-server:latest}"
BASE_REPO_TARBALL="${MB_BASE_REPO_TARBALL:-https://codeload.github.com/metabrainz/musicbrainz-docker/tar.gz/master}"
ensure_base_image() {
  local img="$BASE_IMAGE_NAME" tmp
  local image_present=0
  if docker image inspect "$img" >/dev/null 2>&1; then
    image_present=1
    echo "[setup] base image $img present locally; will verify before skipping build"
  fi
  # Query upstream commit SHA for master branch so we can skip building when
  # the built image already matches that SHA. If this check fails, we'll
  # proceed with a build.
  upstream_sha=""
  upstream_sha=$(curl -fsSL "https://api.github.com/repos/metabrainz/musicbrainz-docker/commits/master" 2>/dev/null | grep -m1 '"sha"' | sed -E 's/[^[:alnum:]]*"sha"[:space:]*"([a-f0-9]+)".*/\1/') || true
  if [[ -n "$upstream_sha" ]]; then
    echo "[setup] upstream master commit: $upstream_sha"
    # If an image exists, check existing image label against upstream commit
    if [[ $image_present -eq 1 && "${FORCE_BUILD,,}" != "true" ]]; then
      existing_sha=$(docker image inspect --format '{{index .Config.Labels "lightbrainz.upstream_sha"}}' "$img" 2>/dev/null || true)
      if [[ -n "$existing_sha" && "$existing_sha" == "$upstream_sha" ]]; then
        echo "[setup] local image $img matches upstream commit $upstream_sha; skipping build"
        return 0
      fi
    fi
  else
    echo "[setup] warning: could not determine upstream commit SHA; will build image"
  fi

  echo "[setup] building base image $img from upstream 'master' tarball..."
  tmp=$(mktemp -d)
  tarball="$tmp/upstream.tar.gz"
  echo "[setup] downloading upstream tarball to $tarball..."
  if ! curl -fsSL "$BASE_REPO_TARBALL" -o "$tarball"; then
    echo "ERROR: failed to download upstream repository tarball $BASE_REPO_TARBALL" >&2
    rm -rf "$tmp" || true
    return 1
  fi
  # compute tarball checksum for later verification
  if command -v sha256sum >/dev/null 2>&1; then
    tarball_sha256=$(sha256sum "$tarball" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    tarball_sha256=$(shasum -a 256 "$tarball" | awk '{print $1}')
  else
    tarball_sha256=""
  fi
  if [[ -n "$tarball_sha256" ]]; then
    echo "[setup] upstream tarball sha256: $tarball_sha256"
  else
    echo "[setup] warning: sha256 utility not available; skipping tarball checksum"
  fi
  echo "[setup] extracting tarball..."
  if ! tar -xzf "$tarball" -C "$tmp" --strip-components=1; then
    echo "ERROR: failed to extract upstream repository tarball $BASE_REPO_TARBALL" >&2
    rm -rf "$tmp" || true
    return 1
  fi
  echo "[setup] downloaded upstream sources; locating build context..."
  # Prefer build context at build/musicbrainz (as upstream repo structures Dockerfile there)
  if [[ -d "$tmp/build/musicbrainz" ]]; then
    build_ctx="$tmp/build/musicbrainz"
    echo "[setup] using build context $build_ctx"
  else
    build_ctx="$tmp"
    echo "[setup] using build context $build_ctx"
  fi
  # compute build-context checksum so we can verify local images built from
  # the exact same sources and skip rebuilding when appropriate
  build_ctx_sha256=""
  if command -v sha256sum >/dev/null 2>&1; then
    build_ctx_sha256=$(tar -C "$build_ctx" -c . | sha256sum | awk '{print $1}') || true
  elif command -v shasum >/dev/null 2>&1; then
    build_ctx_sha256=$(tar -C "$build_ctx" -c . | shasum -a 256 | awk '{print $1}') || true
  fi
  if [[ -n "$build_ctx_sha256" ]]; then
    echo "[setup] build context sha256: $build_ctx_sha256"
    if [[ $image_present -eq 1 && "${FORCE_BUILD,,}" != "true" ]]; then
      existing_build_sha=$(docker image inspect --format '{{index .Config.Labels "lightbrainz.build_context_sha256"}}' "$img" 2>/dev/null || true)
      if [[ -n "$existing_build_sha" && "$existing_build_sha" == "$build_ctx_sha256" ]]; then
        echo "[setup] local image $img matches build-context checksum; skipping build"
        rm -rf "$tmp" || true
        return 0
      fi
    fi
  else
    echo "[setup] warning: sha256 utility not available; skipping build-context checksum verification"
  fi
  echo "[setup] starting docker build (this may take several minutes)"
  # Build with a label so we can detect whether the image corresponds to a
  # particular upstream commit in future runs.
  build_cmd=(docker build -t "$img")
  if [[ -n "$upstream_sha" ]]; then
    build_cmd+=(--label "lightbrainz.upstream_sha=$upstream_sha")
  fi
  if [[ -n "$tarball_sha256" ]]; then
    build_cmd+=(--label "lightbrainz.upstream_tarball_sha256=$tarball_sha256")
  fi
  if [[ -n "$build_ctx_sha256" ]]; then
    build_cmd+=(--label "lightbrainz.build_context_sha256=$build_ctx_sha256")
  fi
  build_cmd+=("$build_ctx")
  if "${build_cmd[@]}"; then
    echo "[setup] built and tagged base image $img"
    rm -rf "$tmp" || true
    return 0
  else
    echo "ERROR: failed to build base image $img from upstream sources" >&2
    rm -rf "$tmp" || true
    return 1
  fi
}

resolve_path() {
  local p="$1" base
  [[ -z "$p" ]] && return 1
  if [[ "$p" = /* ]]; then
    printf '%s' "$p"
    return 0
  fi
  # If PROJECT_ROOT is set (when the script extracted into build/), prefer
  # placing host directories under PROJECT_ROOT so persistent data lives outside
  # the transient build directory.
  if [[ -n "${PROJECT_ROOT:-}" ]]; then
    base="$PROJECT_ROOT"
  else
    base="$SCRIPT_DIR"
  fi
  printf '%s' "$base/${p#./}"
}

# Determine data directories from .env (fall back to prior defaults under
# the repo if a variable is not set). This lets users override where data is
# stored by editing .env.
DB_DIR="$(resolve_path "${MB_DB_DATA:-volumes/musicbrainz-db}")"
SOLR_DIR="$(resolve_path "${MB_SOLR_DATA:-volumes/musicbrainz-search}")"
REDIS_DIR="$(resolve_path "${MB_REDIS_DATA:-volumes/musicbrainz-redis}")"
HA_DIR="$(resolve_path "${HA_OUTPUT_DIR:-volumes/hearring-aid-data}")"

STATE_DIR="$PROJECT_ROOT/state"
echo "[setup] host directories to be created:"
echo "  DB_DIR:    $DB_DIR"
echo "  SOLR_DIR:  $SOLR_DIR"
echo "  REDIS_DIR: $REDIS_DIR"
echo "  HA_DIR:    $HA_DIR"
echo "  STATE_DIR: $STATE_DIR"
mkdir -p "$DB_DIR" "$SOLR_DIR" "$REDIS_DIR" "$HA_DIR" "$STATE_DIR"
echo "[setup] created host directories."

wait_healthy() {
  local svc="$1"; local timeout="${2:-900}"; local start now status cid
  start="$(date +%s)"
  cid="$(docker compose ps -q "$svc" | tr -d '\r')"
  [[ -n "$cid" ]] || { echo "Service $svc not running"; return 1; }
  while true; do
    status="$(docker inspect -f '{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "")"
    [[ "$status" == "healthy" ]] && return 0
    now="$(date +%s)"
    if (( now - start > timeout )); then
      echo "Timed out waiting for $svc to be healthy (last status=$status)"
      return 1
    fi
    sleep 2
  done
}

env_val() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | head -n1 | cut -d= -f2-; }

echo "Starting core services: musicbrainz-db, redis, search..."
docker compose up -d musicbrainz-db redis search

echo "Waiting for database to be healthy..."
wait_healthy musicbrainz-db || echo "Warning: db health not reported healthy; continuing"

echo "Running bootstrap (dumps import)..."
if [[ -n "${MB_DUMPS_URL:-}" ]]; then
  echo "[setup] checking MB_DUMPS_URL: $MB_DUMPS_URL"
  if command -v curl >/dev/null 2>&1; then
    if curl -I --max-time 10 "$MB_DUMPS_URL" >/dev/null 2>&1; then
      curl -I --max-time 10 "$MB_DUMPS_URL" | egrep -i 'HTTP/|Content-Length:|Last-Modified:|Date:' || true
    else
      echo "[setup] warning: MB_DUMPS_URL $MB_DUMPS_URL not reachable via HEAD" >&2
    fi
  fi
fi
if ! ensure_base_image || ! ensure_builder_image || ! docker compose run --build --rm mb-bootstrap; then
  echo "[setup] Bootstrap failed; replication may catch up."
fi

echo "Starting services: musicbrainz, mb-replicator, mb-indexer, hearring-aid..."
docker compose up -d musicbrainz mb-replicator mb-indexer hearring-aid

token="$(env_val MB_REPLICATION_ACCESS_TOKEN || true)"
if [[ -n "${token:-}" ]]; then
  echo "Triggering one replication cycle..."
  if ! docker compose exec -T mb-replicator bash -lc '/scripts/replicate.sh'; then
    echo "[setup] One-shot replication failed; scheduled job will retry."
  fi
else
  echo "No replication token set; skipping immediate replication."
fi

MB_PORT="$(env_val MB_WEB_PORT || true)"; MB_PORT="${MB_PORT:-5800}"
echo "Checking MusicBrainz web at http://localhost:${MB_PORT} ..."
ok=0
for i in {1..60}; do
  if curl -fsS -m 5 "http://localhost:${MB_PORT}" >/dev/null; then ok=1; break; fi
  sleep 2
done || true
if [[ "$ok" == "1" ]]; then
  echo "MusicBrainz web is responding."
else
  echo "MusicBrainz web did not respond yet; containers may still be warming up."
fi

echo "One-shot setup complete. MusicBrainz: http://localhost:${MB_PORT}"
