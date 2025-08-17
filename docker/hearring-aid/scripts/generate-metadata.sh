#!/usr/bin/env bash
set -euo pipefail

CONN="host=${MB_DB_HOST} port=${MB_DB_PORT} dbname=${MB_DB_NAME} user=${MB_DB_USER} password=${MB_DB_PASS} sslmode=${MB_DB_SSLMODE}"

mkdir -p "${OUTPUT_DIR}"
echo "[hearring-aid] (placeholder) Exporting metadata to ${OUTPUT_DIR} using ${CONN}"
# TODO: implement per self-hosted-mirror-setup.md
# hearring-aid export --conn "${CONN}" --out "${OUTPUT_DIR}"

echo "[hearring-aid] Done."
