#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " Silo-to-Silo: Batch Replication Jobs (mcli batch)"
echo "=================================================="

docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli alias set source http://silo-node1:9000 glynacadmin glynacinternpass2026 > /dev/null
    mcli alias set target http://silo-target:9000 glynacadmin glynacinternpass2026 > /dev/null

    mcli mb source/silo-batch-src 2>/dev/null || true
    mcli mb target/silo-batch-tgt 2>/dev/null || true

    echo '[+] Writing source data file for batch job...'
    echo 'silo batch replicated payload block' | mcli pipe source/silo-batch-src/data/batch-item-1.txt

    echo '[+] Creating targeted batch replication job definition...'
    cat << 'YAML' > /tmp/run-replicate.yaml
replicate:
  apiVersion: v1
  source:
    type: minio
    bucket: silo-batch-src
    prefix: data/
  target:
    type: minio
    bucket: silo-batch-tgt
    prefix: data/
    endpoint: "http://silo-target:9000"
    credentials:
      accessKey: "glynacadmin"
      secretKey: "glynacinternpass2026"
YAML

    echo '[+] Submitting batch replication job to source cluster...'
    mcli batch start source/ /tmp/run-replicate.yaml
    
    echo '[+] Waiting 6s for batch worker execution...'
    sleep 6

    echo '[+] Verifying target object sync...'
    mcli ls target/silo-batch-tgt/data/
    echo '[+] Checking replicated payload:'
    mcli cat target/silo-batch-tgt/data/batch-item-1.txt
  "

echo ""
echo "[PASS] Batch replication job completed."
