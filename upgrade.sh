#!/usr/bin/env bash
set -euo pipefail

# Simple upgrade script that updates core files from the public repo without using git.
# - Backs up existing files to backups/upgrade-<timestamp>/
# - Downloads files from raw.githubusercontent.com
# - If --apply is provided, runs ./setup.sh after updating

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f .env ]]; then
  echo "ERROR: .env file not found in ${SCRIPT_DIR}."
  echo "Create and customize .env before upgrading (cp .env.example .env)."
  exit 1
fi

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
  shift || true
fi

# Default files to update (relative paths)
DEFAULT_FILES=(
  "setup.sh"
  "setup.ps1"
  "docker-compose.yml"
)

FILES=()
if [[ $# -gt 0 ]]; then
  FILES=("$@")
else
  FILES=("${DEFAULT_FILES[@]}")
fi

TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="backups/upgrade-${TS}"
mkdir -p "$BACKUP_DIR"

BASE_RAW="https://raw.githubusercontent.com/bballdavis/LightBrainz/main"

echo "Backing up and updating files: ${FILES[*]}"

for f in "${FILES[@]}"; do
  if [[ -f "$f" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$f")"
    cp -a "$f" "$BACKUP_DIR/$f"
    echo "Backed up $f -> $BACKUP_DIR/$f"
  fi

  url="$BASE_RAW/$f"
  echo "Downloading $url..."
  tmpfile=$(mktemp)
  if curl -fsSL "$url" -o "$tmpfile"; then
    # If file exists and identical, skip
    if [[ -f "$f" ]] && cmp -s "$tmpfile" "$f"; then
      echo "No change for $f"
      rm -f "$tmpfile"
      continue
    fi
    mkdir -p "$(dirname "$f")"
    mv "$tmpfile" "$f"
    # Preserve executable bit for scripts
    if [[ "$f" == *.sh || "$f" == "setup.sh" ]]; then
      chmod +x "$f" || true
    fi
    echo "Updated $f"
  else
    echo "Warning: failed to download $url (skipping)"
    rm -f "$tmpfile" || true
  fi
done

echo "Upgrade finished. Replaced files (backed up) are in: $BACKUP_DIR"

if [[ "$APPLY" -eq 1 ]]; then
  echo "Running ./setup.sh as requested (--apply)..."
  ./setup.sh
fi

echo "Done."
