#!/usr/bin/env bash
set -euo pipefail
echo "================================================================"
echo " [!] CRITICAL WARNING: DESTRUCTIVE ACTION"
echo " This will purge all containers, networks, AND local volume data"
echo " in data/minio-single!"
echo "================================================================"
read -p "Are you absolutely sure you want to purge data? (y/N): " confirm
if [[ "${confirm,,}" == "y" ]]; then
  docker compose -p minio-single -f compose/minio-single.yml down -v
  rm -rf data/minio-single/*
  echo "[+] MinIO single-node environment completely reset."
else
  echo "[-] Aborted."
fi
