# Sub-Task 2: Manifest Verification Toolkit & Baseline Ingestion

## Goal
Construct an automated manifest extraction script to capture cryptographic checksums (ETag), S3 version IDs, payload sizes, custom metadata, and tagging counts. This manifest serves as the ground truth for verifying data integrity and parity across MinIO and Silo clusters.

## Environment
- **Host**: ThinkPad T460 (Windows 10, Git Bash)
- **Engine**: Docker Desktop Compose v2
- **Network**: `migration-net`
- **Cluster**: 4-node MinIO baseline (`compose/minio-cluster.yml`)
- **Parity**: `EC:2` (Reed-Solomon erasure coding)
- **Date**: 2026-09-28

## Implemented Tooling
- `scripts/manifest_toolkit.sh`: Queries target S3 buckets/prefixes via `mcli`, streaming JSON telemetry to the host environment to parse:
  - Object Key
  - Version ID
  - Size (bytes)
  - ETag (MD5/cryptographic digest)
  - User Metadata (`X-Amz-Meta-*`)
  - Tag count

## Step-by-Step Procedure & Verification
1. Bootstrapped 4-node MinIO cluster and validated 4/4 nodes online with `EC:2`.
   - *Result*: PASS.
2. Created test bucket `test-bucket` with bucket versioning enabled.
   - *Result*: PASS.
3. Uploaded synthetic payload with custom metadata (`project=glynac;tier=standard`) and tags (`environment=lab&classification=confidential`).
   - *Result*: PASS.
4. Executed `scripts/manifest_toolkit.sh minio_local/test-bucket docs/02-manifest-toolkit/evidence/minio-manifest.tsv`.
   - *Result*: PASS (captured exact ETag, Version ID, and metadata).

## Evidence Artifacts
- `docs/02-manifest-toolkit/evidence/minio-manifest.tsv`: Tab-separated manifest artifact.

## Conclusion
The manifest extraction toolkit functions as required and produces deterministic, comparable output for subsequent migration and parity testing against Silo.
