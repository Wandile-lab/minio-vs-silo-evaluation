#!/usr/bin/env bash
set -euo pipefail

echo "[*] Stopping MinIO Distributed Cluster..."
docker compose -f compose/minio-distributed.yml down
echo "[+] Distributed cluster stopped cleanly. Disk volumes preserved."
