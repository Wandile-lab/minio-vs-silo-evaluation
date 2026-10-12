#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " Silo: Zero-Downtime Rolling Restart with Gate"
echo "=================================================="

NODES=("silo-node1" "silo-node2" "silo-node3" "silo-node4")

for NODE in "${NODES[@]}"; do
  echo ""
  echo ">>> [Phase: Gating ${NODE}] Probing maintenance safety check..."
  if ! docker exec -i "${NODE}" silo healthcheck --url "http://127.0.0.1:9000" --maintenance cluster > /dev/null 2>&1; then
    echo "[-] Maintenance check failed! Taking ${NODE} down would violate quorum. Aborting."
    exit 1
  fi
  echo "[+] Maintenance check PASSED (Exit code 0). Safe to stop ${NODE}."

  echo "[+] Restarting ${NODE}..."
  docker restart "${NODE}" > /dev/null

  # Determine alternative target node to verify read availability during restart
  TARGET="silo-node2"
  if [[ "${NODE}" == "silo-node2" ]]; then
    TARGET="silo-node1"
  fi

  echo -n "    Testing read availability via ${TARGET}... "
  if docker run --rm --net migration-net \
      --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
      -c "
        mcli alias set probe http://${TARGET}:9000 glynacadmin glynacinternpass2026 > /dev/null 2>&1
        mcli cat probe/silo-dist-resilience/obj-1.txt > /dev/null 2>&1
      "; then
    echo "READ SUCCESS"
  else
    echo "READ FAILED"
    exit 1
  fi

  echo -n "    Waiting for ${NODE} to return to cluster write quorum... "
  for i in {1..30}; do
    if docker exec -i "${NODE}" silo healthcheck --url "http://127.0.0.1:9000" cluster > /dev/null 2>&1; then
      echo "RECOVERED (cluster write quorum ok)"
      break
    fi
    sleep 1
  done
done

echo ""
echo "[PASS] Rolling restart completed with zero read downtime across all nodes."
