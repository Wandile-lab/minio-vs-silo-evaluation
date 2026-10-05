#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo " DEV-907: IAM, Access Control & Policy Validation"
echo "=================================================="

# 1. Add User and Attach Built-in 'readonly' Policy
echo "[+] Creating restricted user 'readonlyuser'..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli --insecure admin user add minio_single readonlyuser ReadOnlyPass2026! || true
    mcli --insecure admin policy attach minio_single readonly --user readonlyuser
  "

# 2. Provision Service Account for readonlyuser
echo "[+] Provisioning Service Account for readonlyuser..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure admin user svcacct add minio_single readonlyuser --json > /tmp/sa_out.json

SA_ACCESS=$(docker run --rm -i python:3.11-slim python -c "import sys, json; print(json.load(sys.stdin).get('accessKey'))" < /tmp/sa_out.json)
SA_SECRET=$(docker run --rm -i python:3.11-slim python -c "import sys, json; print(json.load(sys.stdin).get('secretKey'))" < /tmp/sa_out.json)

echo "[+] Service Account Generated: AccessKey=${SA_ACCESS}"

# 3. Verify Read Access Succeeds via direct GetObject
echo "[+] Verifying Read Access (Expected: SUCCESS)..."
docker run --rm --net migration-net \
  -e MC_HOST_sa="https://${SA_ACCESS}:${SA_SECRET}@minio-single:9000" \
  --entrypoint mcli docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  --insecure cat sa/s3-core-test/range.txt > /tmp/read_test.txt

cat /tmp/read_test.txt && echo ""
echo "[PASS] Read-only service account successfully fetched object payload."

# 4. Verify Unauthorized Write Fails (Access Denied / Insufficient permissions)
echo "[+] Verifying Unauthorized Write (Expected: ACCESS DENIED / INSUFFICIENT PERMISSIONS)..."
set +e
ERR_OUT=$(MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_sa="https://${SA_ACCESS}:${SA_SECRET}@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "echo 'unauthorized write' | mcli --insecure pipe sa/s3-core-test/forbidden.txt" 2>&1)
set -e

echo "${ERR_OUT}"
if echo "${ERR_OUT}" | grep -Ei "access denied|insufficient permissions"; then
  echo "[PASS] Access control boundary strictly enforced: Write rejected with authorization error."
else
  echo "[FAIL] Write operation was not blocked!"
  exit 1
fi

# 5. Verify Anonymous Public Policy
echo "[+] Testing Anonymous Public Access Policy on /public prefix..."
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  -e MC_HOST_minio_single="https://glynacadmin:glynacinternpass2026@minio-single:9000" \
  --entrypoint sh docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z \
  -c "
    mcli --insecure anonymous set download minio_single/s3-core-test/public
    echo 'public open content' | mcli --insecure pipe minio_single/s3-core-test/public/hello.txt
  "

# Fetch anonymously without credentials via curl
MSYS_NO_PATHCONV=1 docker run --rm --net migration-net \
  curlimages/curl:latest \
  -k -s -f https://minio-single:9000/s3-core-test/public/hello.txt > /tmp/anon_fetch.txt

cat /tmp/anon_fetch.txt && echo ""
echo "[PASS] Anonymous public policy retrieval verified."
