#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " Silo Distributed Failure & Quorum Resilience"
echo "=================================================="

probe_cluster() {
  local tag="$1"
  local target_node="$2"

  echo -n "[Probe: ${tag}] Testing READ via ${target_node}... "
  if docker run --rm --net migration-net \
      --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
      -c "
        mcli alias set probe http://${target_node}:9000 glynacadmin glynacinternpass2026 > /dev/null 2>&1
        mcli cat probe/silo-dist-resilience/obj-1.txt > /dev/null 2>&1
      "; then
    echo "READ SUCCESS"
  else
    echo "READ FAILED"
  fi

  echo -n "[Probe: ${tag}] Testing WRITE via ${target_node}... "
  if docker run --rm --net migration-net \
      --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
      -c "
        mcli alias set probe http://${target_node}:9000 glynacadmin glynacinternpass2026 > /dev/null 2>&1
        echo 'probe-write-${tag}' | mcli pipe probe/silo-dist-resilience/probe-${tag}.txt > /dev/null 2>&1
      "; then
    echo "WRITE SUCCESS"
  else
    echo "WRITE FAILED (Quorum Blocked)"
  fi
}

echo ""
echo "--- SCENARIO 1: Stop 1 Node (silo-node4) [N-1 Fault Tolerance] ---"
docker stop silo-node4 > /dev/null
probe_cluster "1-node-down" "silo-node1"

echo ""
echo "--- SCENARIO 2: Stop 2nd Node (silo-node3) [Exceeding Parity EC:2] ---"
docker stop silo-node3 > /dev/null
probe_cluster "2-nodes-down" "silo-node1"

echo ""
echo "--- SCENARIO 3: Recover Nodes & Verify Healing ---"
docker start silo-node3 > /dev/null
docker start silo-node4 > /dev/null
sleep 6

probe_cluster "recovered" "silo-node1"

echo ""
echo "[+] Validating drive status after recovery..."
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli alias set cluster http://silo-node1:9000 glynacadmin glynacinternpass2026 > /dev/null
    mcli admin info cluster
  "
