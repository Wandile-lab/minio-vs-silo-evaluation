#!/usr/bin/env bash
set -euo pipefail

echo "[*] Starting MinIO 4-Node Distributed Cluster..."
docker compose -f compose/minio-distributed.yml up -d

echo "[+] Waiting for all 4 nodes to form quorum and initialize..."
sleep 10
docker compose -f compose/minio-distributed.yml ps
