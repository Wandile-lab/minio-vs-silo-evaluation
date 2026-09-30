# DEV-905: Repository Setup, Version Pinning & Local Compose Lab

## Goal
Establish a reproducible, clean Docker Compose lab on Profile B specifications. Verify that the pinned MinIO community baseline boots cleanly, terminates TLS via self-signed certificates, enforces healthcheck endpoints, and preserves object data across stack teardown without volume deletion flags.

## Environment & Specifications (Profile B Fallback)
- **Host**: ThinkPad T460 (Windows 10, Git Bash Msys)
- **Host Specs**: 4 Logical Cores, 8 GB System RAM, 130 GB Free Local SSD
- **Docker Engine**: v29.8.0
- **Docker Compose**: v5.5.1
- **Network**: `migration-net` (bridge)
- **Storage**: Bind mount targeting `data/minio-single`
- **Topology**: Single-node MinIO baseline (`compose/minio-single.yml`)
- **Date**: 2026-09-30

## Pinned Software Releases
- **MinIO Baseline**: `docker.io/pgsty/minio:RELEASE.2026-08-04T00-00-00Z`
- **Pigsty Silo Evaluation Candidate**: `docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z`
- **Tooling Client**: `mcli` pinned to the Silo release image

## Acceptance Criteria Validation

| Criterion | Implementation | Observed Result | Status |
| :--- | :--- | :--- | :--- |
| **Minimum Spec Verification** | `scripts/lab-check.sh` | Confirmed 4 cores, 8GB RAM, local SSD | PASS |
| **Stack Health & Boot** | `compose/minio-single.yml` | Healthcheck passing on `/minio/health/live` | PASS |
| **TLS / HTTPS In-Transit** | Self-signed X.509 (`certs/`) | `API: https://...` on port 9000 | PASS |
| **Lifecycle Persistence** | `lab-down.sh` & `lab-up.sh` | Ingested object read back intact without `-v` | PASS |
| **Stack Destruction Safeguard**| `scripts/lab-reset.sh` | Explicit interactive confirmation gate | PASS |

## Evidence Artifacts
- `docs/01-repo-versions-and-lab/evidence/lab-check.txt`
- `docs/01-repo-versions-and-lab/evidence/minio-single-tls-admin-info.txt`
- `docs/01-repo-versions-and-lab/evidence/minio-single-persistence.txt`

## How to Reproduce
1. Generate certificates:
   ```bash
   MSYS_NO_PATHCONV=1 openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout certs/private.key -out certs/public.crt -subj "/CN=minio-single/O=Lab"
Start lab: ./scripts/lab-up.sh

Stop lab: ./scripts/lab-down.sh

Reset lab: ./scripts/lab-reset.sh
