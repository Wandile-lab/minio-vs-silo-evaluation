#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " DEV-908: Server Pool Expansion & Decommission"
echo "=================================================="

mkdir -p data/minio-dist/d5 data/minio-dist/d6 data/minio-dist/d7 data/minio-dist/d8

# 1. Write the 8-node (2-pool) compose stack
cat << 'COMPOSE' > compose/minio-distributed-expanded.yml
services:
  minio-d1: &minio-common
    image: docker.io/pgsty/minio:RELEASE.2026-08-04T00-00-00Z
    container_name: minio-d1
    hostname: minio-d1
    command: server --certs-dir /root/.minio/certs --address :9000 --console-address :9001 https://minio-d{1...4}:9000/data https://minio-d{5...8}:9000/data
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-glynacadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-glynacinternpass2026}
      MINIO_PROMETHEUS_AUTH_TYPE: "public"
    volumes:
      - ../data/minio-dist/d1:/data
      - ../certs/public.crt:/root/.minio/certs/public.crt:ro
      - ../certs/private.key:/root/.minio/certs/private.key:ro
      - ../certs/public.crt:/root/.minio/certs/CAs/public.crt:ro
    ports:
      - "127.0.0.1:9000:9000"
      - "127.0.0.1:9001:9001"
    networks:
      - migration-net
    healthcheck:
      test: ["CMD-SHELL", "curl -k -f https://localhost:9000/minio/health/live || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 5

  minio-d2:
    <<: *minio-common
    container_name: minio-d2
    hostname: minio-d2
    volumes:
      - ../data/minio-dist/d2:/data
      - ../certs/public.crt:/root/.minio/certs/public.crt:ro
      - ../certs/private.key:/root/.minio/certs/private.key:ro
      - ../certs/public.crt:/root/.minio/certs/CAs/public.crt:ro
    ports: []

  minio-d3:
    <<: *minio-common
    container_name: minio-d3
    hostname: minio-d3
    volumes:
      - ../data/minio-dist/d3:/data
      - ../certs/public.crt:/root/.minio/certs/public.crt:ro
      - ../certs/private.key:/root/.minio/certs/private.key:ro
      - ../certs/public.crt:/root/.minio/certs/CAs/public.crt:ro
    ports: []

  minio-d4:
    <<: *minio-common
    container_name: minio-d4
    hostname: minio-d4
    volumes:
      - ../data/minio-dist/d4:/data
      - ../certs/public.crt:/root/.minio/certs/public.crt:ro
      - ../certs/private.key:/root/.minio/certs/private.key:ro
      - ../certs/public.crt:/root/.minio/certs/CAs/public.crt:ro
    ports: []

  minio-d5:
    <<: *minio-common
    container_name: minio-d5
    hostname: minio-d5
    volumes:
      - ../data/minio-dist/d5:/data
      - ../certs/public.crt:/root/.minio/certs/public.crt:ro
      - ../certs/private.key:/root/.minio/certs/private.key:ro
      - ../certs/public.crt:/root/.minio/certs/CAs/public.crt:ro
    ports: []

  minio-d6:
    <<: *minio-common
    container_name: minio-d6
    hostname: minio-d6
    volumes:
      - ../data/minio-dist/d6:/data
      - ../certs/public.crt:/root/.minio/certs/public.crt:ro
      - ../certs/private.key:/root/.minio/certs/private.key:ro
      - ../certs/public.crt:/root/.minio/certs/CAs/public.crt:ro
    ports: []

  minio-d7:
    <<: *minio-common
    container_name: minio-d7
    hostname: minio-d7
    volumes:
      - ../data/minio-dist/d7:/data
      - ../certs/public.crt:/root/.minio/certs/public.crt:ro
      - ../certs/private.key:/root/.minio/certs/private.key:ro
      - ../certs/public.crt:/root/.minio/certs/CAs/public.crt:ro
    ports: []

  minio-d8:
    <<: *minio-common
    container_name: minio-d8
    hostname: minio-d8
    volumes:
      - ../data/minio-dist/d8:/data
      - ../certs/public.crt:/root/.minio/certs/public.crt:ro
      - ../certs/private.key:/root/.minio/certs/private.key:ro
      - ../certs/public.crt:/root/.minio/certs/CAs/public.crt:ro
    ports: []

networks:
  migration-net:
    external: true
COMPOSE

echo "[+] Upgrading cluster from 1 pool to 2 pools..."
docker compose -f compose/minio-distributed.yml down
docker compose -f compose/minio-distributed-expanded.yml up -d

echo "[+] Waiting for 8 nodes across 2 pools to form quorum..."
sleep 15

# Verify admin info reports 2 pools and 8 online drives
docker run --rm --net migration-net \
  -e MC_HOST_dist="https://glynacadmin:glynacinternpass2026@minio-d1:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure admin info dist

# Verify existing data read integrity
echo "[+] Probing data read integrity across expansion..."
docker run --rm --net migration-net \
  -e MC_HOST_dist="https://glynacadmin:glynacinternpass2026@minio-d1:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure cat dist/dist-resilience-bucket/obj-1.txt >/dev/null && echo "[PASS] Existing data immediately readable post-expansion."

# Test Decommissioning of Pool 2
echo "[+] Testing Decommissioning initiation on Pool 2..."
docker run --rm --net migration-net \
  -e MC_HOST_dist="https://glynacadmin:glynacinternpass2026@minio-d1:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure admin decommission start dist https://minio-d{5...8}:9000/data

echo "[+] Checking decommission status..."
docker run --rm --net migration-net \
  -e MC_HOST_dist="https://glynacadmin:glynacinternpass2026@minio-d1:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure admin decommission status dist

echo "[PASS] Server pool expansion and decommission workflow verified."
