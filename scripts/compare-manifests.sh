#!/usr/bin/env bash
set -euo pipefail

MANIFEST_A="${1:?Usage: $0 <baseline_manifest.tsv> <target_manifest.tsv>}"
MANIFEST_B="${2:?Usage: $0 <baseline_manifest.tsv> <target_manifest.tsv>}"

echo "=================================================="
echo " MANIFEST INTEGRITY & TAMPER DETECTION REPORT"
echo "=================================================="
echo "Baseline: ${MANIFEST_A}"
echo "Target:   ${MANIFEST_B}"
echo "--------------------------------------------------"

DIFF_OUTPUT=$(diff -u "${MANIFEST_A}" "${MANIFEST_B}" || true)

if [[ -z "${DIFF_OUTPUT}" ]]; then
  echo "[PASS] 100% Manifest Integrity Parity. Zero discrepancies detected."
  exit 0
else
  echo "[FAIL] Discrepancies detected across manifests:"
  echo "${DIFF_OUTPUT}"
  exit 1
fi
