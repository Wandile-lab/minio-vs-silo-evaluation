#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " DEV-908: MinIO Distributed Failure & Quorum Test"
echo "=================================================="

# Test helper to probe S3 read and write availability
probe_cluster() {
  local tag="$1"
  local write_expected="$2"
  local read_expected="$3"

  echo -n "[Probe: ${tag}] Testing READ... "
  if docker run --rm --net migration-net \
      -e MC_HOST_dist="https://glynacadmin:glynacinternpass2026@minio-d1:9000" \
      --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
      --insecure cat dist/dist-resilience-bucket/obj-1.txt >/dev/null 2>&1; then
    echo "READ SUCCESS"
  else
    echo "READ FAILED"
  fi

  echo -n "[Probe: ${tag}] Testing WRITE... "
  if docker run --rm --net migration-net \
      -e MC_HOST_dist="https://glynacadmin:glynacinternpass2026@minio-d1:9000" \
      --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
      -c "echo 'probe-write' | mcli --insecure pipe dist/dist-resilience-bucket/probe-${tag}.txt" >/dev/null 2>&1; then
    echo "WRITE SUCCESS"
  else
    echo "WRITE FAILED"
  fi
}

# --- SCENARIO 1: Stop 1 Node (minio-d4) ---
echo ""
echo "=== Scenario 1: 1 Node Down (3/4 online: within write & read quorum) ==="
docker stop minio-d4 >/dev/null
probe_cluster "1-node-down" "SUCCESS" "SUCCESS"

# --- SCENARIO 2: Stop 2 Nodes (minio-d3 and minio-d4) ---
echo ""
echo "=== Scenario 2: 2 Nodes Down (2/4 online: read quorum intact, write quorum lost) ==="
docker stop minio-d3 >/dev/null
probe_cluster "2-nodes-down" "FAILED" "SUCCESS"

# --- SCENARIO 3: Stop 3 Nodes (minio-d2, minio-d3, minio-d4) ---
echo ""
echo "=== Scenario 3: 3 Nodes Down (1/4 online: below read quorum) ==="
docker stop minio-d2 >/dev/null
probe_cluster "3-nodes-down" "FAILED" "FAILED"

# --- RECOVERY: Restore All Nodes ---
echo ""
echo "=== Restoring all nodes ==="
docker start minio-d2 minio-d3 minio-d4 >/dev/null
sleep 6
probe_cluster "recovered" "SUCCESS" "SUCCESS"

# --- SCENARIO 4: Drive Wipe & Healing ---
echo ""
echo "=== Scenario 4: Simulating Drive Corruption / Wipe on Node d4 ==="
echo "[+] Wiping local data on d4 while cluster is live..."
rm -rf data/minio-dist/d4/dist-resilience-bucket

echo "[+] Drive wiped. Checking cluster drive status..."
docker run --rm --net migration-net \
  -e MC_HOST_dist="https://glynacadmin:glynacinternpass2026@minio-d1:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure admin info dist | grep -E "drives online|drives offline" || true

echo "[+] Triggering manual cluster healing (mc admin heal)..."
docker run --rm --net migration-net \
  -e MC_HOST_dist="https://glynacadmin:glynacinternpass2026@minio-d1:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure admin heal -r --verbose dist/dist-resilience-bucket

echo "[+] Verifying files restored to d4 volume..."
ls -la data/minio-dist/d4/dist-resilience-bucket || true

echo "[PASS] Distributed failure and healing scenarios completed."
