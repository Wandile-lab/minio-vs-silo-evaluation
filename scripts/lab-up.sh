#!/usr/bin/env bash
set -euo pipefail
echo "[*] Bringing up MinIO single-node baseline..."
docker compose -p minio-single --env-file .env -f compose/minio-single.yml up -d
echo "[+] Waiting for healthcheck status..."
sleep 3
docker compose -p minio-single -f compose/minio-single.yml ps
