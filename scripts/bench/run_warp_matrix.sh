#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${1:-minio-node1:9000}"
TOPOLOGY_NAME="${2:-distributed}"
PROTOCOL="${3:-http}" # "http" or "https"
OUT_DIR="docs/06-minio-performance-baseline/evidence/${TOPOLOGY_NAME}"
mkdir -p "${OUT_DIR}"

ACCESS_KEY="glynacadmin"
SECRET_KEY="glynacinternpass2026"

TLS_FLAGS=""
if [ "${PROTOCOL}" = "https" ]; then
  TLS_FLAGS="--tls --insecure"
fi

echo "======================================================================"
echo " Running DEV-910 Warp Benchmark Matrix: ${TOPOLOGY_NAME} (${PROTOCOL}://${TARGET_HOST})"
echo "======================================================================"

run_bench() {
  local name="$1"
  local cmd="$2"
  shift 2
  echo ""
  echo ">>> [Profile: ${name}] Running ${cmd}..."
  
  MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
    minio/warp:latest "${cmd}" \
    --host="${TARGET_HOST}" \
    --access-key="${ACCESS_KEY}" \
    --secret-key="${SECRET_KEY}" \
    ${TLS_FLAGS} \
    --no-color \
    --duration=15s \
    "$@" | tee "${OUT_DIR}/${name}.txt"
}

# 1. Small Objects (64 KiB)
run_bench "small-put" put --obj.size=64KiB --concurrent=4 --bucket="bench-small-${TOPOLOGY_NAME}"
run_bench "small-get" get --obj.size=64KiB --objects=100 --concurrent=4 --bucket="bench-small-${TOPOLOGY_NAME}"
run_bench "small-delete" delete --obj.size=64KiB --objects=1600 --concurrent=4 --bucket="bench-del-${TOPOLOGY_NAME}"

# 2. Large Objects (8 MiB)
run_bench "large-put" put --obj.size=8MiB --concurrent=2 --bucket="bench-large-${TOPOLOGY_NAME}"
run_bench "large-get" get --obj.size=8MiB --objects=20 --concurrent=2 --bucket="bench-large-${TOPOLOGY_NAME}"

# 3. Mixed Workload
run_bench "mixed" mixed --objects=100 --concurrent=4 --bucket="bench-mixed-${TOPOLOGY_NAME}"

# 4. Multipart (32 MiB total: 4 parts of 8 MiB)
run_bench "multipart" multipart --part.size=8MiB --parts=4 --concurrent=2 --bucket="bench-mp-${TOPOLOGY_NAME}"

echo ""
echo "======================================================================"
echo " Completed benchmark suite for ${TOPOLOGY_NAME}."
echo " Output preserved in: ${OUT_DIR}/"
echo "======================================================================"
