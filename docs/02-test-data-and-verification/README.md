# DEV-906: Test Data Seeding & Verification Toolkit

## Goal
Generate a repeatable synthetic test dataset that exercises standard and advanced S3 storage behaviors (multi-size objects, deep and flat partitioning, multi-versioning, delete markers, and WORM object locking) on Profile B specifications. Build and validate an integrity manifest toolkit capable of detecting missing versions, altered bytes, and tampered records.

## Environment & Target
- **Target**: `minio-single` (v2026-08-04) over TLS HTTPS (`https://minio-single:9000`)
- **Execution Engine**: Docker Engine v29.8.0, Compose v5.5.1
- **Parser Engine**: Containerized Python 3.11 (`python:3.11-slim`)
- **Date**: 2026-09-30

## Seeded Dataset Breakdown

| Category | Target Bucket / Path | Object Count / Size | Characteristics |
| :--- | :--- | :--- | :--- |
| **Small Objects (KB)** | `standard-data-bucket/flat/` | 15 files x 4 KiB | Custom user metadata (`environment=test`) & tags (`project=eval`) |
| **Deep Partitioning** | `standard-data-bucket/deep/year=2026/month=09/dept=eng/` | 15 files x 4 KiB | Deep hierarchical prefix layout |
| **Medium / Versioned** | `standard-data-bucket/versioned/document.bin` | 2 versions x 10 MiB | Multi-version PUT sequence |
| **Delete Markers** | `standard-data-bucket/versioned/deleted_doc.bin` | 1 delete marker | Versioned soft deletion marker |
| **Large Multipart** | `standard-data-bucket/large/large_500m.bin` | 1 file x 500 MiB | Profile B-safe multipart scale payload |
| **WORM Compliance** | `locked-dataset-bucket/compliance-record.txt` | 1 file (24 B) | `COMPLIANCE` retention mode (7 days) |
| **WORM Governance** | `locked-dataset-bucket/governance-record.txt` | 1 file (24 B) | `GOVERNANCE` retention mode (7 days) + active `Legal Hold` |

## Acceptance Criteria Validation

| Criterion | Implementation | Observed Result | Status |
| :--- | :--- | :--- | :--- |
| **Scripted & Repeatable Seeding** | `scripts/seed-data.sh` | Automated generation across all required size classes and lock types | PASS |
| **Manifest Generation** | `scripts/manifest_toolkit.sh` | Manifests captured keys, version IDs, sizes, ETags, and metadata TSV rows | PASS |
| **Parity Self-Check** | `scripts/compare-manifests.sh` | 100% parity verified on baseline vs baseline | PASS |
| **Tamper Detection** | `scripts/compare-manifests.sh` | Detected missing line and flagged injected bad checksum record | PASS |

## Evidence Artifacts
- `docs/02-test-data-and-verification/evidence/standard-baseline-manifest.tsv`
- `docs/02-test-data-and-verification/evidence/locked-baseline-manifest.tsv`
- `docs/02-test-data-and-verification/evidence/tamper-detection-test.txt`

## How to Reproduce
1. Seed test dataset:
   ```bash
   ./scripts/seed-data.sh minio_single
./scripts/manifest_toolkit.sh minio_single/standard-data-bucket docs/02-test-data-and-verification/evidence/standard-baseline-manifest.tsv
./scripts/manifest_toolkit.sh minio_single/locked-dataset-bucket docs/02-test-data-and-verification/evidence/locked-baseline-manifest.tsv
./scripts/compare-manifests.sh docs/02-test-data-and-verification/evidence/standard-baseline-manifest.tsv docs/02-test-data-and-verification/evidence/standard-baseline-manifest.tsv
