#!/usr/bin/env bash
set -euo pipefail

TARGET_BUCKET="${1:?Usage: $0 <target_alias/bucket> <output_manifest_path>}"
OUTPUT_FILE="${2:?Usage: $0 <target_alias/bucket> <output_manifest_path>}"

mkdir -p "$(dirname "${OUTPUT_FILE}")"
echo "[*] Querying objects from: ${TARGET_BUCKET}"

# Write TSV header
printf "KEY\tVERSION_ID\tSIZE\tETAG\tMETADATA\n" > "${OUTPUT_FILE}"

# Query JSON from mcli and pipe into containerized Python for clean TSV formatting
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure find "${TARGET_BUCKET}" --json \
  | docker run --rm -i python:3.11-slim python -c '
import sys, json

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        data = json.loads(line)
        key = data.get("key", "")
        version_id = data.get("versionId", "null")
        size = str(data.get("size", 0))
        etag = data.get("etag", "")
        meta = json.dumps(data.get("metadata", {}))
        if key:
            sys.stdout.write(f"{key}\t{version_id}\t{size}\t{etag}\t{meta}\n")
    except Exception:
        pass
' >> "${OUTPUT_FILE}"

echo "[+] Manifest generated successfully at: ${OUTPUT_FILE}"
