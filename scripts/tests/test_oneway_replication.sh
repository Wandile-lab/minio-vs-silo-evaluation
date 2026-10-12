#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " Silo-to-Silo: One-Way Bucket Replication Test"
echo "=================================================="

SRC_URL="http://silo-node1:9000"
TGT_URL="http://silo-target:9000"
USER="glynacadmin"
PASS="glynacinternpass2026"
BUCKET="silo-repl-test"

echo "[+] Setting up aliases and buckets..."
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli alias set src ${SRC_URL} ${USER} ${PASS} > /dev/null
    mcli alias set tgt ${TGT_URL} ${USER} ${PASS} > /dev/null

    # Create buckets with versioning (replication prerequisite)
    mcli mb src/${BUCKET} 2>/dev/null || true
    mcli version enable src/${BUCKET}
    mcli mb tgt/${BUCKET} 2>/dev/null || true
    mcli version enable tgt/${BUCKET}

    echo '[+] Configuring bucket replication rule (src -> tgt)...'
    mcli replicate add src/${BUCKET} \
      --remote-bucket tgt/${BUCKET} \
      --priority 1 \
      --replicate \"existing-objects,delete,delete-marker\"

    echo '[+] Verifying replication configuration...'
    mcli replicate ls src/${BUCKET}

    echo '[+] Seeding new objects to source bucket...'
    for i in \$(seq 1 5); do
      echo \"silo replication payload object \$i\" | mcli pipe src/${BUCKET}/repl-\$i.txt
    done
  "

echo "[+] Waiting 6s for async replication sync to target..."
sleep 6

echo "[+] Verifying replicated objects on target..."
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli alias set tgt ${TGT_URL} ${USER} ${PASS} > /dev/null
    mcli ls tgt/${BUCKET}
    echo '[+] Checking payload parity on target for repl-1.txt:'
    mcli cat tgt/${BUCKET}/repl-1.txt
  "

echo ""
echo "[PASS] Silo-to-Silo One-Way Bucket Replication verified."
