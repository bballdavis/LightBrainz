#!/usr/bin/env bash
set -euo pipefail

# Placeholder for search reindex steps (if required)
entities_csv="${MB_INDEX_ENTITIES:-artist,release}"
IFS=',' read -ra ENTITIES <<< "$entities_csv"
echo "[hearring-aid] (placeholder) Reindexing entities: ${entities_csv}"
for e in "${ENTITIES[@]}"; do
	e_trimmed="$(echo "$e" | xargs)"
	[[ -z "$e_trimmed" ]] && continue
	echo "[hearring-aid] -> reindex $e_trimmed"
	# TODO: call actual indexer (e.g., python -m sir reindex --entity-type "$e_trimmed")
done
