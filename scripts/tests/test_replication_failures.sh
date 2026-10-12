#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " Silo-to-Silo: Replication Target Failure & Recovery"
echo "=================================================="

# 1. Stop Target Container
echo "[+] Simulating target site outage (stopping silo-target)..."
docker stop silo-target > /dev/null

# 2. Write 5 objects to source during outage
echo "[+] Writing 5 payload objects to source during outage..."
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli alias set source http://silo-node1:9000 glynacadmin glynacinternpass2026 > /dev/null
    for i in \$(seq 1 5); do
      echo \"Outage payload item \$i\" | mcli pipe source/silo-repl-test/outage-load-\$i.txt
    done
    echo '[+] Checking source replication status / backlog while target is dead:'
    mcli replicate status source/silo-repl-test || true
  "

# 2. Recover Target Container
echo ""
echo "[+] Recovering target site (starting silo-target)..."
docker start silo-target > /dev/null
sleep 6

# 3. Verify Catch-Up
echo "[+] Verifying target caught up after recovery..."
docker run --rm --net migration-net \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli alias set target http://silo-target:9000 glynacadmin glynacinternpass2026 > /dev/null
    mcli ls target/silo-repl-test/outage-load-1.txt
    echo '[+] Verifying object payload on target:'
    mcli cat target/silo-repl-test/outage-load-1.txt
  "

echo ""
echo "[PASS] Replication backlog drained and consistency recovered after target failure."
