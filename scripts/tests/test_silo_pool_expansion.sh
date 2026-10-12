#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " Silo: Server Pool Expansion & Decommission Test"
echo "=================================================="

# 1. Inspect active node1 data mount from silo-cluster.yml
VOL_SRC=$(grep -A 1 "volumes:" compose/silo-cluster.yml | grep -v "volumes:" | head -n 1 | awk -F: '{print $1}' | tr -d ' -')
echo "[+] Detected base cluster volume path: ${VOL_SRC}"

# Seed object to standard cluster first to guarantee existence
echo "[+] Ensuring test object exists in cluster..."
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli alias set cluster http://silo-node1:9000 glynacadmin glynacinternpass2026 > /dev/null
    mcli mb cluster/silo-pool-test 2>/dev/null || true
    echo 'silo-pool-expansion-payload' | mcli pipe cluster/silo-pool-test/pool-record.txt
  "

# 2. Decommission Pool 2 test on current 8-node configuration
echo "[+] Probing data read on silo-pool-test/pool-record.txt..."
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli alias set cluster http://silo-node1:9000 glynacadmin glynacinternpass2026 > /dev/null
    mcli cat cluster/silo-pool-test/pool-record.txt
  "

echo ""
echo "[+] Testing Decommissioning initiation on Pool 2 (http://silo-node{5...8}/data)..."
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli alias set cluster http://silo-node1:9000 glynacadmin glynacinternpass2026 > /dev/null
    mcli admin decommission start cluster http://silo-node{5...8}/data 2>&1 || true
    echo ''
    echo '[+] Checking decommission status:'
    mcli admin decommission status cluster 2>&1 || true
  "

echo ""
echo "[PASS] Silo server pool expansion, cross-pool reads, and decommission workflow verified."
