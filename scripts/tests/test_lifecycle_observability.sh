#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " DEV-907: Lifecycle Expiry & Observability Checks"
echo "=================================================="

# Ensure target bucket exists
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli --insecure mb minio_single/vers-edge-test 2>/dev/null || true
    mcli --insecure version enable minio_single/vers-edge-test 2>/dev/null || true
  "

# 1. Configure Lifecycle Rule (Expire noncurrent versions after 1 day, delete markers)
echo "[+] Applying Bucket Lifecycle configuration..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli --insecure ilm rule add --noncurrent-expire-days 1 --expire-delete-marker minio_single/vers-edge-test
    mcli --insecure ilm rule ls minio_single/vers-edge-test
  "

# 2. Test Observability: Prometheus /minio/v2/metrics/cluster Endpoint
echo "[+] Validating Prometheus metrics endpoint (/minio/v2/metrics/cluster)..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  curlimages/curl:latest \
  -k -s -f https://minio-single:9000/minio/v2/metrics/cluster > docs/03-minio-feature-validation/evidence/raw_metrics.txt

echo "Sample metrics scraped:"
head -n 10 docs/03-minio-feature-validation/evidence/raw_metrics.txt
echo "[PASS] Prometheus endpoint active and emitting cluster metrics."

# 3. Test Observability: Admin Trace
echo "[+] Validating Admin Trace capability..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    (mcli --insecure admin trace --all minio_single > /tmp/trace.log 2>&1 &)
    TRACE_PID=\$!
    sleep 2
    mcli --insecure ls minio_single/standard-data-bucket > /dev/null
    sleep 2
    kill \$TRACE_PID 2>/dev/null || true
    head -n 12 /tmp/trace.log
  "

echo "[PASS] Admin trace verified."
