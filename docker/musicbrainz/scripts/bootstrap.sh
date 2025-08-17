#!/usr/bin/env bash
set -euo pipefail

host="${MB_DB_HOST:-musicbrainz-db}"
port="${MB_DB_PORT:-5432}"
db="${MB_DB_NAME:-musicbrainz}"
user="${MB_DB_USER:-abc}"
pass="${MB_DB_PASSWORD:-abc}"
sslmode="${MB_DB_SSLMODE:-disable}"

export PGPASSWORD="$pass"

# Wait for DB
until psql -h "$host" -p "$port" -U "$user" -d "$db" -c "select 1" >/dev/null 2>&1; do
  echo "[mb-bootstrap] Waiting for database..."
  sleep 2
done

echo "[mb-bootstrap] Checking for existing schema..."
if psql -h "$host" -p "$port" -U "$user" -d "$db" -Atc "select to_regclass('artist') is not null;" | grep -qi t; then
  echo "[mb-bootstrap] Schema detected; skipping import."
  exit 0
fi

echo "[mb-bootstrap] No schema detected."
if [[ "${MB_IMPORT_DUMPS:-true}" == "true" ]]; then
  if command -v createdb.sh >/dev/null 2>&1; then
    echo "[mb-bootstrap] Creating DB from official dumps via createdb.sh (-fetch)"
    # Make sure createdb.sh talks to our DB container
    export MUSICBRAINZ_POSTGRES_SERVER="$host"
    export POSTGRES_USER="$user"
    export POSTGRES_PASSWORD="$pass"
      # If operator has pre-approved data usage, create the appropriate
      # marker file so createdb.sh / fetch-dump.sh will not prompt interactively.
      # Set MB_DUMPS_CONSENT=non-commercial or MB_DUMPS_CONSENT=commercial
      # in your environment or .env to skip the interactive question.
      if [[ -n "${MB_DUMPS_CONSENT:-}" ]]; then
        case "${MB_DUMPS_CONSENT}" in
          commercial)
            echo "[mb-bootstrap] Marking dumps dir as commercial use (MB_DUMPS_CONSENT=commercial)"
            mkdir -p /media/dbdump || true
            touch /media/dbdump/.for-commercial-use || true
            ;;
          non-commercial|noncommercial|non)
            echo "[mb-bootstrap] Marking dumps dir as non-commercial use (MB_DUMPS_CONSENT=non-commercial)"
            mkdir -p /media/dbdump || true
            touch /media/dbdump/.for-non-commercial-use || true
            ;;
          *)
            echo "[mb-bootstrap] MB_DUMPS_CONSENT set to unknown value: ${MB_DUMPS_CONSENT}; ignoring"
            ;;
        esac
      fi
    # If a custom base URL provided, pass it through expected var
    if [[ -n "${MB_DUMPS_URL:-}" ]]; then
      # musicbrainz-docker uses MUSICBRAINZ_BASE_DOWNLOAD_URL as base; MB_DUMPS_URL can be a dir like fullexport/LATEST
      export MUSICBRAINZ_BASE_DOWNLOAD_URL="${MB_DUMPS_URL}"
    fi
    set +e
    createdb.sh -fetch 2>&1 | tee /var/log/createdb.log
    rc=${PIPESTATUS[0]}
    set -e
    if [[ $rc -ne 0 ]]; then
      echo "[mb-bootstrap] createdb.sh failed with exit code $rc; proceeding without dumps (replication can catch up)."
    else
      echo "[mb-bootstrap] createdb.sh completed successfully."
    fi
  else
    echo "[mb-bootstrap] createdb.sh not found; attempting to fetch from upstream..."
    if command -v curl >/dev/null 2>&1; then
      set +e
      curl -fsSL "https://raw.githubusercontent.com/metabrainz/musicbrainz-docker/master/build/musicbrainz/scripts/createdb.sh" -o /usr/local/bin/createdb.sh
      dl_rc=$?
      set -e
      if [[ $dl_rc -eq 0 ]]; then
        chmod +x /usr/local/bin/createdb.sh || true
        echo "[mb-bootstrap] Running fetched createdb.sh (-fetch)"
        export MUSICBRAINZ_POSTGRES_SERVER="$host"
        export POSTGRES_USER="$user"
        export POSTGRES_PASSWORD="$pass"
          if [[ -n "${MB_DUMPS_CONSENT:-}" ]]; then
            case "${MB_DUMPS_CONSENT}" in
              commercial)
                echo "[mb-bootstrap] Marking dumps dir as commercial use (MB_DUMPS_CONSENT=commercial)"
                mkdir -p /media/dbdump || true
                touch /media/dbdump/.for-commercial-use || true
                ;;
              non-commercial|noncommercial|non)
                echo "[mb-bootstrap] Marking dumps dir as non-commercial use (MB_DUMPS_CONSENT=non-commercial)"
                mkdir -p /media/dbdump || true
                touch /media/dbdump/.for-non-commercial-use || true
                ;;
              *)
                echo "[mb-bootstrap] MB_DUMPS_CONSENT set to unknown value: ${MB_DUMPS_CONSENT}; ignoring"
                ;;
            esac
          fi
        if [[ -n "${MB_DUMPS_URL:-}" ]]; then
          export MUSICBRAINZ_BASE_DOWNLOAD_URL="${MB_DUMPS_URL}"
        fi
        set +e
        createdb.sh -fetch 2>&1 | tee /var/log/createdb.log
        rc=${PIPESTATUS[0]}
        set -e
        if [[ $rc -ne 0 ]]; then
          echo "[mb-bootstrap] createdb.sh (fetched) failed with exit code $rc; proceeding without dumps (replication can catch up)."
        else
          echo "[mb-bootstrap] createdb.sh (fetched) completed successfully."
        fi
      else
        echo "[mb-bootstrap] Could not fetch createdb.sh; continuing with limited fallback."
      fi
    else
      echo "[mb-bootstrap] curl is not available to fetch createdb.sh."
    fi
    if [[ -n "${MB_DUMPS_URL:-}" ]]; then
      case "$MB_DUMPS_URL" in
        *.sql.gz)
          echo "[mb-bootstrap] Importing plain SQL dump (.sql.gz)"
          curl -fsSL "$MB_DUMPS_URL" | gunzip -c | psql -h "$host" -p "$port" -U "$user" -d "$db" || true ;;
        *.sql)
          echo "[mb-bootstrap] Importing plain SQL dump (.sql)"
          curl -fsSL "$MB_DUMPS_URL" | psql -h "$host" -p "$port" -U "$user" -d "$db" || true ;;
        *)
          echo "[mb-bootstrap] Unsupported dump format for direct import. Provide a .sql/.sql.gz or use our default fullexport with an image that contains createdb.sh."
          ;;
      esac
    else
      echo "[mb-bootstrap] No MB_DUMPS_URL provided. Skipping import; replication can catch up."
    fi
  fi
else
  echo "[mb-bootstrap] Skipping dump import (MB_IMPORT_DUMPS=false). Replication will be the only source of data."
fi
