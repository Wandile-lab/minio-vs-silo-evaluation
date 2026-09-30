#!/usr/bin/env bash
# Manifest Toolkit for Data Integrity & Parity Audit
# Usage: ./scripts/manifest_toolkit.sh <alias/bucket> <output_file>

set -euo pipefail

TARGET="${1:-}"
OUTPUT_FILE="${2:-}"

if [[ -z "$TARGET" || -z "$OUTPUT_FILE" ]]; then
  echo "Usage: $0 <alias/bucket> <output_file>"
  echo "Example: $0 minio_local/test-bucket docs/02-manifest-toolkit/evidence/minio-manifest.tsv"
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

# Header schema per Epic requirements
printf "KEY\tVERSION_ID\tSIZE\tETAG\tMETADATA\n" > "$OUTPUT_FILE"

echo "[*] Querying objects from: $TARGET"

# Query objects list in JSON format
OBJ_KEYS=$(MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_local="http://${MINIO_ROOT_USER:-glynacadmin}:${MINIO_ROOT_PASSWORD:-glynacinternpass2026}@minio-node1:9000" \
  -e MC_HOST_silo_local="http://${MINIO_ROOT_USER:-glynacadmin}:${MINIO_ROOT_PASSWORD:-glynacinternpass2026}@silo-node1:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  ls --json "$TARGET" | sed -n 's/.*"key":"\([^"]*\)".*/\1/p')

if [[ -z "$OBJ_KEYS" ]]; then
  # Fallback if key is named "name" in some versions
  OBJ_KEYS=$(MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
    -e MC_HOST_minio_local="http://${MINIO_ROOT_USER:-glynacadmin}:${MINIO_ROOT_PASSWORD:-glynacinternpass2026}@minio-node1:9000" \
    -e MC_HOST_silo_local="http://${MINIO_ROOT_USER:-glynacadmin}:${MINIO_ROOT_PASSWORD:-glynacinternpass2026}@silo-node1:9000" \
    --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
    ls --json "$TARGET" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
fi

for KEY in $OBJ_KEYS; do
  echo "  -> Processing object: $KEY"
  STAT_JSON=$(MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
    -e MC_HOST_minio_local="http://${MINIO_ROOT_USER:-glynacadmin}:${MINIO_ROOT_PASSWORD:-glynacinternpass2026}@minio-node1:9000" \
    -e MC_HOST_silo_local="http://${MINIO_ROOT_USER:-glynacadmin}:${MINIO_ROOT_PASSWORD:-glynacinternpass2026}@silo-node1:9000" \
    --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
    stat --json "$TARGET/$KEY")

  SIZE=$(echo "$STAT_JSON" | sed -n 's/.*"size":\([0-9]*\).*/\1/p')
  ETAG=$(echo "$STAT_JSON" | sed -n 's/.*"etag":"\([^"]*\)".*/\1/p')
  VER_ID=$(echo "$STAT_JSON" | sed -n 's/.*"versionID":"\([^"]*\)".*/\1/p')
  META=$(echo "$STAT_JSON" | sed -n 's/.*"metadata":{\([^}]*\)}.*/{\1}/p')

  printf "%s\t%s\t%s\t%s\t%s\n" "$KEY" "$VER_ID" "$SIZE" "$ETAG" "$META" >> "$OUTPUT_FILE"
done

# Sort rows deterministically (ignoring header)
(head -n 1 "$OUTPUT_FILE" && tail -n +2 "$OUTPUT_FILE" | sort) > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

echo "[+] Manifest generated successfully at: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
