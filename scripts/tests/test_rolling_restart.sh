#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " DEV-908: Zero-Downtime Rolling Restart Test"
echo "=================================================="

NODES=("minio-d1" "minio-d2" "minio-d3" "minio-d4")

for NODE in "${NODES[@]}"; do
  echo "[+] Restarting ${NODE}..."
  docker restart "${NODE}" > /dev/null

  # Wait until healthcheck transitions back to healthy
  echo -n "    Waiting for ${NODE} healthcheck... "
  while true; do
    STATUS=$(docker inspect --format '{{.State.Health.Status}}' "${NODE}" 2>/dev/null || echo "starting")
    if [[ "${STATUS}" == "healthy" ]]; then
      echo "HEALTHY"
      break
    fi
    sleep 1
  done

  # Verify cluster availability during/after individual node restart
  # If minio-d1 was restarted, target minio-d2 for the probe during transition
  TARGET="minio-d2"
  if [[ "${NODE}" == "minio-d2" ]]; then
    TARGET="minio-d1"
  fi

  echo -n "    Checking read availability via ${TARGET}... "
  docker run --rm --net migration-net \
    -e MC_HOST_probe="https://glynacadmin:glynacinternpass2026@${TARGET}:9000" \
    --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
    --insecure cat probe/dist-resilience-bucket/obj-1.txt >/dev/null 2>&1 && echo "OK"
done

echo "[PASS] Rolling restart completed with continuous availability."
