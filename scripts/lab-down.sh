#!/usr/bin/env bash
set -euo pipefail
echo "[*] Gracefully stopping MinIO single-node baseline..."
docker compose -p minio-single -f compose/minio-single.yml down
echo "[+] Containers stopped. Data preserved on disk."
