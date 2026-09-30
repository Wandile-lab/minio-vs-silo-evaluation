#!/usr/bin/env bash
set -euo pipefail

TARGET_ALIAS="${1:-minio_single}"
BASE_DIR="/tmp/s3-seed"
mkdir -p "${BASE_DIR}"

echo "[*] Seeding synthetic test dataset against: ${TARGET_ALIAS}"

# 1. Initialize Buckets
echo "[+] Initializing buckets..."
docker run --rm --net migration-net \
  -e MC_HOST_target="${MC_HOST_minio_single:-https://glynacadmin:glynacinternpass2026@minio-single:9000}" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure mb target/standard-data-bucket || true

docker run --rm --net migration-net \
  -e MC_HOST_target="${MC_HOST_minio_single:-https://glynacadmin:glynacinternpass2026@minio-single:9000}" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure mb --with-lock target/locked-dataset-bucket || true

docker run --rm --net migration-net \
  -e MC_HOST_target="${MC_HOST_minio_single:-https://glynacadmin:glynacinternpass2026@minio-single:9000}" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure version enable target/standard-data-bucket

# 2. Ingest Small Objects & Deep Layouts
echo "[+] Generating and ingesting small files (KB) & deep hierarchies..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_target="${MC_HOST_minio_single:-https://glynacadmin:glynacinternpass2026@minio-single:9000}" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c '
    for i in $(seq 1 15); do
      head -c 4096 /dev/urandom > /tmp/small_$i.bin
      mcli --insecure cp --attr "environment=test;index=$i" --tags "project=eval&tier=bronze" /tmp/small_$i.bin target/standard-data-bucket/flat/small_$i.bin
      mcli --insecure cp /tmp/small_$i.bin target/standard-data-bucket/deep/year=2026/month=09/dept=eng/small_$i.bin
    done
  '

# 3. Ingest Medium Objects (MB) & Versioning Cycles
echo "[+] Generating medium files (10MB) with multiple versions and delete markers..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_target="${MC_HOST_minio_single:-https://glynacadmin:glynacinternpass2026@minio-single:9000}" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c '
    head -c 10485760 /dev/urandom > /tmp/med_v1.bin
    head -c 10485760 /dev/urandom > /tmp/med_v2.bin
    # Upload Version 1
    mcli --insecure cp --tags "state=initial" /tmp/med_v1.bin target/standard-data-bucket/versioned/document.bin
    # Upload Version 2
    mcli --insecure cp --tags "state=updated" /tmp/med_v2.bin target/standard-data-bucket/versioned/document.bin
    # Generate Delete Marker
    mcli --insecure cp /tmp/med_v1.bin target/standard-data-bucket/versioned/deleted_doc.bin
    mcli --insecure rm target/standard-data-bucket/versioned/deleted_doc.bin
  '

# 4. Ingest Profile B Large Multipart Object (500MB)
echo "[+] Generating 500MB multipart-scale object (Profile B safe)..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_target="${MC_HOST_minio_single:-https://glynacadmin:glynacinternpass2026@minio-single:9000}" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c '
    head -c 524288000 /dev/urandom > /tmp/large_500m.bin
    mcli --insecure cp /tmp/large_500m.bin target/standard-data-bucket/large/large_500m.bin
    rm -f /tmp/large_500m.bin
  '

# 5. Object Lock Data (Compliance, Governance, Legal Hold)
echo "[+] Seeding Object-Locked objects..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_target="${MC_HOST_minio_single:-https://glynacadmin:glynacinternpass2026@minio-single:9000}" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c '
    echo "Compliance WORM payload" > /tmp/comp.txt
    echo "Governance WORM payload" > /tmp/gov.txt
    mcli --insecure cp /tmp/comp.txt target/locked-dataset-bucket/compliance-record.txt
    mcli --insecure retention set COMPLIANCE 7d target/locked-dataset-bucket/compliance-record.txt

    mcli --insecure cp /tmp/gov.txt target/locked-dataset-bucket/governance-record.txt
    mcli --insecure retention set GOVERNANCE 7d target/locked-dataset-bucket/governance-record.txt
    mcli --insecure legalhold set target/locked-dataset-bucket/governance-record.txt
  '

echo "[+] Seeding complete across all required categories."
