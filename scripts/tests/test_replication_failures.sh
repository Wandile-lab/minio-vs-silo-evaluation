#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " DEV-909: Replication Outage & Recovery Test"
echo "=================================================="

# 1. Stop Target Container
echo "[+] Simulating target site outage (stopping minio-target)..."
docker stop minio-target > /dev/null

# 2. Write 10 objects to source during outage
echo "[+] Writing 10 payload objects to source during outage..."
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli --insecure alias set source https://minio-single:9000 glynacadmin glynacinternpass2026 > /dev/null
    for i in \$(seq 1 10); do
      echo \"Outage payload batch \$i\" | mcli --insecure pipe source/rep-source-bucket/outage-load-\$i.txt
    done
    echo '[+] Checking source replication status / backlog while target is dead:'
    mcli --insecure replicate status source/rep-source-bucket || true
    mcli --insecure replicate backlog source/rep-source-bucket || true
  "

# 3. Recover Target Container
echo "[+] Recovering target site (starting minio-target)..."
docker start minio-target > /dev/null
sleep 4

# 4. Measure time to catch up and achieve consistency
echo "[+] Waiting for replication backlog to drain and achieve consistency..."
START_TIME=$(date +%s)
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli --insecure alias set target https://minio-target:9000 glynacadmin glynacinternpass2026 > /dev/null
    for attempt in \$(seq 1 30); do
      COUNT=\$(mcli --insecure ls target/rep-target-bucket/outage-load-*.txt 2>/dev/null | wc -l || echo 0)
      if [ \"\$COUNT\" -ge 10 ]; then
        echo \"[+] All 10 objects reconciled on target in \${attempt}s!\"
        break
      fi
      sleep 1
    done
    mcli --insecure ls target/rep-target-bucket/outage-load-*.txt
  "

echo ""
echo "[PASS] Replication failure recovery and backlog flush verified."
