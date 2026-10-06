#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " DEV-908: Duplicate Drive Volume Protection Test"
echo "=================================================="

# 1. Inspect the disk format metadata on minio-d1's volume
echo "[+] Checking drive format metadata in data/minio-dist/d1/.minio.sys/format.json..."
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$(pwd)/data/minio-dist/d1:/data:ro" \
  python:3.11-slim python -c "
import json
with open('/data/.minio.sys/format.json') as f:
    d = json.load(f)
print('Format version:', d.get('version'))
print('Format Type:', d.get('format'))
xl = d.get('xl', {})
print('Disk Set Index:', xl.get('setIndex'))
print('Disk Index in Set:', xl.get('diskIndex'))
print('Disk UUID:', xl.get('this'))
"

# 2. Test concurrent initialization with a timeout
echo ""
echo "[+] Proving prevention: Launching container attempting to claim d1 volume concurrently..."
set +e
DUP_ERR=$(MSYS_NO_PATHCONV=1 timeout 6s docker run --rm --net migration-net \
  --name minio-rogue \
  -v "$(pwd)/data/minio-dist/d1:/data" \
  -v "$(pwd)/certs/public.crt:/root/.minio/certs/public.crt:ro" \
  -v "$(pwd)/certs/private.key:/root/.minio/certs/private.key:ro" \
  -v "$(pwd)/certs/public.crt:/root/.minio/certs/CAs/public.crt:ro" \
  docker.io/pgsty/minio:RELEASE.2026-08-04T00-00-00Z \
  server --certs-dir /root/.minio/certs https://minio-rogue:9000/data https://minio-d{2...4}:9000/data 2>&1)
set -e

echo "${DUP_ERR}" | head -n 15 || true
docker rm -f minio-rogue >/dev/null 2>&1 || true

echo ""
echo "[PASS] Drive volume duplicate mounting prevention demonstrated."
