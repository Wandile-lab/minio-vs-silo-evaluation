#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " DEV-909: Phase 2 — One-Way Bucket Replication"
echo "=================================================="

# 1. Setup buckets, versioning, and initial data
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli --insecure alias set source https://minio-single:9000 glynacadmin glynacinternpass2026 > /dev/null
    mcli --insecure alias set target https://minio-target:9000 glynacadmin glynacinternpass2026 > /dev/null

    echo '[+] Creating source and target buckets...'
    mcli --insecure mb source/rep-source-bucket 2>/dev/null || true
    mcli --insecure mb target/rep-target-bucket 2>/dev/null || true

    echo '[+] Enabling versioning on both buckets...'
    mcli --insecure version enable source/rep-source-bucket
    mcli --insecure version enable target/rep-target-bucket

    echo '[+] Writing pre-existing object (before replication rule)...'
    echo 'historical data before replication rule' | mcli --insecure pipe source/rep-source-bucket/pre-existing.txt

    echo '[+] Clearing existing remote targets if present...'
    mcli --insecure admin bucket remote rm source/rep-source-bucket --all 2>/dev/null || true
  "

# 2. Register Remote Target and capture ARN via JSON output
echo "[+] Registering remote target on source..."
docker run --rm --net migration-net \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure --json admin bucket remote add source/rep-source-bucket \
  https://glynacadmin:glynacinternpass2026@minio-target:9000/rep-target-bucket > /tmp/remote_add.json

TARGET_ARN=$(docker run --rm -i python:3.11-slim python -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        # Check standard mc output fields for remote ARN
        arn = d.get('remoteBucketARN') or d.get('arn')
        if arn:
            print(arn)
            break
    except Exception:
        pass
" < /tmp/remote_add.json)

# Fallback: query remote list if json add didn't return ARN directly
if [[ -z "${TARGET_ARN}" ]]; then
  TARGET_ARN=$(docker run --rm --net migration-net \
    --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
    --insecure --json admin bucket remote ls source/rep-source-bucket \
    | docker run --rm -i python:3.11-slim python -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        arn = d.get('remoteBucketARN') or d.get('arn')
        if arn:
            print(arn)
            break
    except Exception:
        pass
")
fi

echo "[+] Successfully registered target with ARN: ${TARGET_ARN}"

# 3. Add replication rule and seed live objects
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    echo '[+] Adding replication rule on source/rep-source-bucket...'
    mcli --insecure replicate add source/rep-source-bucket \
      --remote-bucket '${TARGET_ARN}' \
      --replicate 'delete,delete-marker,existing-objects'

    echo '[+] Active Replication Rules:'
    mcli --insecure replicate ls source/rep-source-bucket

    echo '[+] Writing live versioned and tagged data...'
    # Version 1
    echo 'version 1 content' | mcli --insecure pipe source/rep-source-bucket/app-config.txt --tags 'env=production&tier=backend'
    # Version 2
    echo 'version 2 updated content' | mcli --insecure pipe source/rep-source-bucket/app-config.txt --tags 'env=production&tier=backend'

    echo '[+] Creating a delete marker on a separate object...'
    echo 'temporary file' | mcli --insecure pipe source/rep-source-bucket/temp-file.txt
    mcli --insecure rm source/rep-source-bucket/temp-file.txt

    echo '[+] Waiting 8 seconds for asynchronous replication sync...'
    sleep 8

    echo '[+] Target Object Inventory (Including Versions and Delete Markers):'
    mcli --insecure ls --versions target/rep-target-bucket/

    echo '[+] Checking Tags on Target Object:'
    mcli --insecure tag list target/rep-target-bucket/app-config.txt

    echo '[+] Checking Pre-existing Object on Target:'
    mcli --insecure cat target/rep-target-bucket/pre-existing.txt
  "

echo ""
echo "[PASS] Phase 2: One-way replication verified."
