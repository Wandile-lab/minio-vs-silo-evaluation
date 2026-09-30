#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo " LAB ENVIRONMENT & PROFILE SPEC CHECK"
echo "=========================================="
echo "Timestamp: $(date -u)"
echo "OS / Kernel: $(uname -srmo)"

# CPU Architecture and Count
echo "--- CPU Info ---"
if command -v nproc &>/dev/null; then
  echo "Logical Cores: $(nproc)"
fi

# Memory Check
echo "--- Memory Info ---"
if command -v free &>/dev/null; then
  free -h
elif [[ -f /proc/meminfo ]]; then
  grep MemTotal /proc/meminfo
fi

# Disk Space Check
echo "--- Storage / SSD Info ---"
df -h .

# Docker & Compose Versions
echo "--- Docker Environment ---"
docker --version
docker compose version

# Verification of migration-net
echo "--- Network Check ---"
if docker network inspect migration-net &>/dev/null; then
  echo "Network 'migration-net': ACTIVE"
else
  echo "Network 'migration-net': NOT FOUND (run: docker network create migration-net)"
fi

echo "=========================================="
echo "Profile Target: Profile B (Fallback, <=16GB RAM, Local SSD mount)"
echo "=========================================="
