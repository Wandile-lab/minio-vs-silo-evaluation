# DEV-909: MinIO Replication Reference Runbook & Architecture Validation

This document serves as the known-good reference runbook and empirical validation record for MinIO bucket and batch replication on the standard baseline (RELEASE.2026-08-04T00-00-00Z)".

---

## 1. Replication Modes & Behavioral Matrix

| Mode / Feature | Tested Command / Flow | Observed Result | Evidence Reference |
| :--- | :--- | :--- | :--- |
| **One-Way Bucket Replication** | `mcli replicate add source/bucket --remote-bucket <TARGET~` | **PASS** | `docs/05-minio-replication/evidence/oneway-replication-verified.txt`|
| **Version Stacking** | Sequential updates to `app-config.txt` (`v1`, `v2`) | **PASS** (UUIDs and ordering preserved) | `docs/05-minio-replication/evidence/oneway-replication-verified.txt`|
| **Delete Marker Sync** | `mcli rm` on versioned object | **PASS** (`DEL` marker replicated as `v2 DEL`) | `docs/05-minio-replication/evidence/oneway-replication-verified.txt`|
| **Tag & Metadata Sync** | `env=production&tier;backend` tags | **PASS** (Preserved across transit) | `docs/05-minio-replication/evidence/oneway-replication-verified.txt`|
| **Active-Active (Two-Way)** | Bidirectional rules; writes originating on Target | **PASS** (Arrived on Source within 6s) | `docs/05-minio-replication/evidence/twoway-replication.txt`|
| **Target Outage Resilience** | 10 writes during complete target container outage | **PASS** (Client writes succeeded; link flagged offline) | `docs/05-minio-replication/evidence/outage-recovery.txt`|
| **Batch Replication Jobs** | `mcli batch generate/start/list` | **PASS** (Batch manifest executed to target prefix) | `docs/05-minio-replication/evidence/batch-replication.txt`|

---

## 2. Operator Runbook: Exact Command Reference

### A. Prerequisites
Both source and target buckets must have versioning enabled prior to configuring replication rules.

```bash
# 1. Register cluster aliases
mcli alias set source https://minio-source:9000 ACCESS_KEY SECRET_KEY
mcli alias set target https://minio-target:9000 ACCESS_KEY SECRET_KEY

# 2. Create buckets and enable versioning
mcli mb source/my-bucket
mcli mb target/my-bucket
mcli version enable source/my-bucket
mcli version enable target/my-bucket
```

### B. Configuring One-Way Bucket Replication
In modern MinIO/Silo releases, `mcli replicate add` directly establishes authentication and remote binding in a unified step:

```bash
mcli replicate add source/my-bucket \
  --remote-bucket https://ACCESS_KEY:SEGRET_KEY@minio-target:9000/my-bucket \
  --replicate "delete,delete-marker,existing-objects" \
  --priority 0
```

### C. Active-Active (Two-Way) Configuration
Run the reciprocal command on the target deployment:

```bash
mcli replicate add target/my-bucket \
  --remote-bucket https://ACCESS_KEY:SECRET_KEY@minio-source:9000/my-bucket \
  --replicate "delete,delete-marker,existing-objects" \
  --priority 0
```

Conflict Resolution: In two-way replication, MinIO evaluates version timestamps via Last-Write-Wins (LWW). Both versions remain preserved in the underlying version stack.

### D. Monitoring & Observability Commands

```bash
# List active rules and target ARN
mcli replicate ls source/my-bucket

# View live wire latency, transfer rates, errors, and link status
mcli replicate status source/my-bucket

# Inspect replication backlog (run inside interactive TTY)
mcli replicate backlog source/my-bucket
```

### E. Manual Resync of Historical or Failed Objects
If existing objects or network partitions require an explicit backfill:

```bash
# Initiate full historical resync
mcli replicate resync start source/my-bucket --remote-bucket TARGET_ARN

# Check resync progress
mcli replicate resync status source/my-bucket --remote-bucket TARGET_ARN
```

### F. Batch Replication Jobs (mc batch)
For high-volume, declarative migration jobs:

```bash
# 1. Generate template
mcli batch generate source/ replicate > replicate-job.yaml

# 2. Submit batch replication job
mcli batch start source replicate-job.yaml

# 3. Check status
mcli batch list source
mcli batch status source JOB_ID
```

---

## 3. Evidence Index
- `docs/05-minio-replication/evidence/initial-deployments-status.txtj- `docs/05-minio-replication/evidence/oneway-replication-verified.txt`
- `docs/05-minio-replication/evidence/twoway-replication.txtj- `docs/05-minio-replication/evidence/outage-recovery.txt`
- `docs/05-minio-replication/evidence/batch-replication.txt`
