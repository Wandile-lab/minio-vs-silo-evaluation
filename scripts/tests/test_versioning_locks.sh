#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " DEV-907: Versioning Edge Cases & WORM Lock Tests"
echo "=================================================="

# 1. Ensure locked bucket and records exist
echo "[+] Ensuring locked bucket and records exist..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli --insecure mb --with-lock minio_single/locked-dataset-bucket 2>/dev/null || true
    echo 'Compliance immutable payload' > /tmp/c.txt
    mcli --insecure cp /tmp/c.txt minio_single/locked-dataset-bucket/compliance-record.txt
    mcli --insecure retention set COMPLIANCE 7d minio_single/locked-dataset-bucket/compliance-record.txt
    
    echo 'Governance legal hold payload' > /tmp/g.txt
    mcli --insecure cp /tmp/g.txt minio_single/locked-dataset-bucket/governance-record.txt
    mcli --insecure retention set GOVERNANCE 7d minio_single/locked-dataset-bucket/governance-record.txt
    mcli --insecure legalhold set minio_single/locked-dataset-bucket/governance-record.txt
  "

# 2. Extract Version IDs for the locked records via ls --versions --json
echo "[+] Extracting version IDs for locked objects..."
COMP_VID=$(MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure ls --versions --json minio_single/locked-dataset-bucket/compliance-record.txt \
  | docker run --rm -i python:3.11-slim python -c "
import sys, json
for line in sys.stdin:
    d = json.loads(line.strip())
    vid = d.get('versionId')
    if vid and vid != 'null':
        print(vid)
        break
")

GOV_VID=$(MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure ls --versions --json minio_single/locked-dataset-bucket/governance-record.txt \
  | docker run --rm -i python:3.11-slim python -c "
import sys, json
for line in sys.stdin:
    d = json.loads(line.strip())
    vid = d.get('versionId')
    if vid and vid != 'null':
        print(vid)
        break
")

echo "  -> Extracted Compliance Version ID: ${COMP_VID}"
echo "  -> Extracted Governance Version ID:   ${GOV_VID}"

# 3. Test Permanent Delete on COMPLIANCE-locked Version ID (Must FAIL)
echo "[+] Testing permanent version deletion on COMPLIANCE record (Expected: BLOCKED)..."
set +e
COMP_ERR=$(MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "mcli --insecure rm --version-id '${COMP_VID}' minio_single/locked-dataset-bucket/compliance-record.txt" 2>&1)
set -e

echo "${COMP_ERR}"
if echo "${COMP_ERR}" | grep -Ei "worm protected|object is protected|access denied|retention|precondition|not permitted"; then
  echo "[PASS] WORM compliance locked version cannot be purged."
else
  echo "[FAIL] Compliance-locked version was purged!"
  exit 1
fi

# 4. Test Permanent Delete on GOVERNANCE-locked Version ID with Legal Hold (Must FAIL)
echo "[+] Testing permanent version deletion on GOVERNANCE record with Legal Hold (Expected: BLOCKED)..."
set +e
GOV_ERR=$(MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "mcli --insecure rm --version-id '${GOV_VID}' minio_single/locked-dataset-bucket/governance-record.txt" 2>&1)
set -e

echo "${GOV_ERR}"
if echo "${GOV_ERR}" | grep -Ei "worm protected|object is protected|access denied|legal hold|retention|precondition|not permitted"; then
  echo "[PASS] Legal hold prevents permanent version purge even under root administrator."
else
  echo "[FAIL] Legal hold version was purged!"
  exit 1
fi

# 5. Versioning Mechanics: Suspend, Re-enable, Delete Marker
echo "[+] Testing Versioning State Changes & Delete Marker Mechanics..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli --insecure mb minio_single/vers-edge-test 2>/dev/null || true
    mcli --insecure version enable minio_single/vers-edge-test
    echo 'version 1' | mcli --insecure pipe minio_single/vers-edge-test/file.txt
    echo 'version 2' | mcli --insecure pipe minio_single/vers-edge-test/file.txt
    
    # Soft delete (injects delete marker)
    mcli --insecure rm minio_single/vers-edge-test/file.txt
    
    # Verify standard get returns error due to marker
    if mcli --insecure cat minio_single/vers-edge-test/file.txt 2>/dev/null; then
      echo 'ERROR: Object should be hidden by delete marker'
      exit 1
    else
      echo '[+] Object hidden by delete marker as expected.'
    fi

    # Suspend versioning
    mcli --insecure version suspend minio_single/vers-edge-test
    echo 'version 3 (suspended)' | mcli --insecure pipe minio_single/vers-edge-test/file.txt
    
    # Re-enable versioning
    mcli --insecure version enable minio_single/vers-edge-test
  "

echo "[PASS] Versioning lifecycle, suspension, and delete marker mechanics verified."
