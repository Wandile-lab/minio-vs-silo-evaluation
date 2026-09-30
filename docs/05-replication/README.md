# Sub-Task 5: Cross-Cluster Asynchronous Replication (MinIO -> Silo)

## Goal
Validate live cross-cluster asynchronous S3 bucket replication between the legacy MinIO cluster (`minio_local`) and Pigsty Silo (`silo_local`). Verify cryptographic checksum alignment, version ID preservation, custom user metadata synchronization, and delete marker propagation.

## Environment
- **Host**: ThinkPad T460 (Windows 10, Git Bash)
- **Engine**: Docker Desktop Compose v2
- **Network**: `migration-net` (bridge)
- **Source**: 4-node MinIO baseline (`http://minio-node1:9000`)
- **Target**: 4-node Pigsty Silo (`http://silo-node1:9000`)
- **Date**: 2026-09-30

## Replication Architecture & Configuration
- **Source Bucket**: `minio_local/replica-bucket` (versioning enabled)
- **Target Bucket**: `silo_local/replica-bucket` (versioning enabled)
- **Target ARN**: Configured via `mcli replicate add` targeting `http://silo-node1:9000/replica-bucket`
- **Replication Scope**: `--replicate "delete,delete-marker,existing-objects"`

## Verification Results

| Characteristic | Source (MinIO Baseline) | Target (Pigsty Silo) | Parity Status |
| :--- | :--- | :--- | :--- |
| **Object Key** | `data.txt` | `data.txt` | PASS (Identical) |
| **Version ID (v1 PUT)** | `547b495b-cfc8-45ba-83a4-26c4459d8437` | `547b495b-cfc8-45ba-83a4-26c4459d8437` | PASS (Preserved) |
| **ETag (Checksum)** | `58b546ad753c8c4db482f64832339320` | `58b546ad753c8c4db482f64832339320` | PASS (Identical) |
| **Object Size** | `49 B` | `49 B` | PASS (Identical) |
| **User Metadata** | `source=upstream-minio; sync=true` | `source=upstream-minio; sync=true` | PASS (Preserved) |
| **Tagging Count** | `2` | `2` | PASS (Preserved) |
| **Replication State** | `COMPLETED` | `REPLICA` | PASS (S3 Standard) |
| **Delete Marker (v2 DEL)**| `0eccff91-53c0-4722-abc5-505b7819c398` | `0eccff91-53c0-4722-abc5-505b7819c398` | PASS (Propagated) |

## Manifest Audit
Executing `diff -u` on the source manifest (`minio-source-manifest.tsv`) and target manifest (`silo-target-manifest.tsv`) produced zero differences, mathematically confirming data and metadata parity.

## Conclusion
Pigsty Silo operates as an active replication receiver for MinIO source clusters without requiring intermediate protocol translation, gateway proxies, or version remapping.
