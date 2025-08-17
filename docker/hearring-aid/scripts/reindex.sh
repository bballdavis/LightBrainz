#!/usr/bin/env bash
set -euo pipefail

# Disabled?
if [[ "${ENABLE_INDEXING:-true}" != "true" ]]; then
	echo "[mb-indexer] ENABLE_INDEXING=false; skipping."
	exit 0
fi

# Placeholder for search reindex steps (if required)
entities_csv="${MB_INDEX_ENTITIES:-artist,release}"
IFS=',' read -ra ENTITIES <<< "$entities_csv"
echo "[hearring-aid] Reindexing entities: ${entities_csv}"
for e in "${ENTITIES[@]}"; do
	e_trimmed="$(echo "$e" | xargs)"
	[[ -z "$e_trimmed" ]] && continue
	echo "[hearring-aid] -> reindex $e_trimmed"
	if command -v python3 >/dev/null 2>&1; then
		python3 -m sir reindex --entity-type "$e_trimmed" || true
	else
		echo "[hearring-aid] sir not available; skipping actual reindex."
	fi
done
