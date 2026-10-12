#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${1:-minio-single:9000}"
TOPOLOGY_NAME="${2:-single-node}"
OUTPUT_DIR="docs/06-minio-performance-baseline/evidence/${TOPOLOGY_NAME}"
mkdir -p "${OUTPUT_DIR}"

ACCESS_KEY="glynacadmin"
SECRET_KEY="glynacinternpass2026"

echo "=========================================================="
echo " Starting Warp Benchmark Suite: ${TOPOLOGY_NAME} (${TARGET_HOST})"
echo "=========================================================="

run_warp() {
  local profile="$1"
  local log_name="$2"
  shift 2
  echo "[+] Running profile: ${profile} (${log_name})..."
  
  MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
    minio/warp:latest "${profile}" \
    --host="${TARGET_HOST}" \
    --access-key="${ACCESS_KEY}" \
    --secret-key="${SECRET_KEY}" \
    --tls --insecure \
    --duration=10s \
    "$@" | tee "${OUTPUT_DIR}/${log_name}.txt"
}

# 1. Small Objects (64KiB)
run_warp put small-put --obj.size=64KiB --concurrent=8 --bucket="bench-small-${TOPOLOGY_NAME}"
run_warp get small-get --obj.size=64KiB --concurrent=8 --bucket="bench-small-${TOPOLOGY_NAME}"

# 2. Large Objects (8MiB, concurrent=2 to prevent host socket exhaustion)
run_warp put large-put --obj.size=8MiB --concurrent=2 --bucket="bench-large-${TOPOLOGY_NAME}"
run_warp get large-get --obj.size=8MiB --concurrent=2 --bucket="bench-large-${TOPOLOGY_NAME}"

# 3. Mixed Workload (Default real-world distribution)
run_warp mixed mixed --concurrent=4 --duration=15s --bucket="bench-mixed-${TOPOLOGY_NAME}"

# 4. Multipart (32MiB total, 8MiB parts)
run_warp multipart multipart --obj.size=32MiB --part.size=8MiB --concurrent=2 --bucket="bench-mp-${TOPOLOGY_NAME}"

# 5. Delete Operations (64KiB)
run_warp delete delete --obj.size=64KiB --concurrent=4 --bucket="bench-del-${TOPOLOGY_NAME}"

echo "=========================================================="
echo " Completed Warp Benchmark Suite for ${TOPOLOGY_NAME}"
echo " Evidence saved in ${OUTPUT_DIR}/"
echo "=========================================================="
