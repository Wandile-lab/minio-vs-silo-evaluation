# Sub-Task 1: Environment Setup & Foundation Verification

## Goal
Establish a reproducible local testing environment for comparing the archived open-source MinIO release against the Pigsty Silo fork under identical constraints (Profile B fallback).

## Environment
- **Host Machine**: ThinkPad T460, Windows 10, Git Bash
- **Docker Engine**: Docker Desktop Compose v2
- **Shared Network**: `migration-net` (bridge)
- **Profile**: Profile B (4 nodes x 1 drive, local SSD bind-mount)
- **Date**: 2026-09-28

## Pinned Artifacts
1. **MinIO Baseline Image**:
   - Reference: `docker.io/pgsty/minio:RELEASE.2026-08-04T00-00-00Z`
   - Digest: `sha256:b6bfe7239bfc83fb90d31612d9704d86039dd714f7904b3f1ad68f211e602372`
   - Release: `RELEASE.2026-08-04T00-00-00Z`
2. **Silo Evaluation Image**:
   - Reference: `docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z`
   - Digest: `sha256:635197cb9f36d01bee221d34d1c7d7960f6a95c48b0b6c01d99cd13bdae51a46`
   - Release: `RELEASE.2026-09-16T00-00-00Z`

## Step-by-Step Procedure
1. Create external bridge network `migration-net`.
   - *Expected*: Docker allocates isolated subnet bridge.
   - *Actual*: PASS (`migration-net` created, ID verified).
2. Query and pull immutable image tags.
   - *Expected*: Byte-level verification via SHA256 digest.
   - *Actual*: PASS (both images pulled and version verified).
3. Secret scanning baseline.
   - *Expected*: Redacted `.env.example`, `.env` ignored by Git.
   - *Actual*: PASS.

## Results Table
| Component | Check | Expected | Actual | Status |
| :--- | :--- | :--- | :--- | :--- |
| `migration-net` | Docker network inspection | Driver: bridge | Driver: bridge | PASS |
| MinIO Image | Digest check | Immutable SHA256 | `sha256:b6bfe...` | PASS |
| Silo Image | Digest check | Immutable SHA256 | `sha256:63519...` | PASS |

## Conclusion
Foundation setup is verified. Both target binaries are pinned and ready for cluster topology definition.
