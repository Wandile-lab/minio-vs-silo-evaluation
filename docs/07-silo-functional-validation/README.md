# DEV-910: Silo Functional Validation (Features, Cluster, Replication)

## Executive Summary
This evaluation tests Silo (`docker.io/pgsty/silo:RELEASE.2026-09-16T00-00-00Z`) against the MinIO baseline across three functional domains: Single-Node Features, Distributed Cluster Resilience, and Replication Modes. All tests reused identical topologies, resource limits, and network environments.

**Overall Verdict: 100% Functional Parity with Significant Operational Improvements in Maintenance Health Checking.**

---

## 1. Feature Parity Matrix (Sub-task 3 Re-execution)

| Feature Area | MinIO Baseline | Silo Result | Delta Classification | Severity | Notes / Evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Core S3 API** | PASS | PASS | Same | None | Boto3 SDK object PUT, GET, DELETE pass with identical headers |
| **User Metadata & Tags** | PASS | PASS | Same | None | Custom `x-amz-meta-*` and S3 object tags preserved |
| **Pre-signed URLs** | PASS | PASS | Same | None | Signature v4 verification passes via `urllib` fetch |
| **IAM & Access Control** | PASS | PASS | Same | None | `readonly` policy attached to user enforces write rejections |
| **Service Accounts** | PASS | PASS | Same | None | Dynamic access/secret key pairs provisioned and functional |
| **Anonymous Public Policy** | PASS | PASS | Same | None | Public bucket download access works without credentials |
| **WORM Compliance Retention** | PASS | PASS | Same | None | Permanent object deletion blocked under `COMPLIANCE` mode |
| **Legal Hold Mechanics** | PASS | PASS | Same | None | Object purge blocked while legal hold is active |
| **Versioning & Markers** | PASS | PASS | Same | None | Delete markers and suspension toggles operate identically |
| **Lifecycle (ILM)** | PASS | PASS | Same | None | Expiration rules for older versions and markers accepted |
| **Prometheus Observability** | PASS | PASS | Same | None | `/minio/v2/metrics/cluster` scraped and structurally identical |

---

## 2. Cluster Resilience & Maintenance (Sub-task 4 Re-execution)

Topology: 4 nodes (`silo-node1..4`), 1 drive per node, EC:2 erasure coding set.

| Test Scenario | MinIO Baseline | Silo Result | Delta Classification | Notes / Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **Maintenance Gate** | N/A (Scripted probe) | PASS | **Improved** | `silo healthcheck --maintenance cluster` (exit code 0) reliably gates safe node shutdowns |
| **Zero-Downtime Rolling Restart** | PASS | PASS | Same | Consecutive node restarts executed with 0 read downtime |
| **1-Node Outage (N-1)** | PASS (Read+Write OK) | PASS (Read+Write OK) | Same | Sustained within EC:2 redundancy budget |
| **2-Node Outage (Parity Exceeded)** | PASS (Read OK, Write Fail) | PASS (Read OK, Write Fail) | Same | Preserved read quorum; write quorum blocked to prevent corruption |
| **Heal & Cluster Recovery** | PASS | PASS | Same | Nodes rejoined, drives returned to 4/4 OK, parity restored |

---

## 3. Silo-to-Silo Replication (Sub-task 5 Re-execution)

Environment: Source cluster (`silo-node1..4`) to Target instance (`silo-target:9000`).

| Mode / Scenario | MinIO Baseline | Silo Result | Delta Classification | Evidence |
| :--- | :--- | :--- | :--- | :--- |
| **One-Way Bucket Replication** | PASS | PASS | Same | Replicated existing objects, deletes, and soft markers |
| **Batch Replication (`mcli batch`)** | PASS | PASS | Same | Schema v1 batch jobs executed with completed status |
| **Target Outage Resilience** | PASS | PASS | Same | Link marked offline; backlog drained automatically upon recovery |

---

## 4. Silo-Only Extras Validation

| Silo Feature | Purpose / Difference | Test Result | Output / Evidence |
| :--- | :--- | :--- | :--- |
| **Native Health Checks** | Probes `live`, `ready`, `cluster`, `cluster-read` without external tools | PASS | All 4 subcommands returned 200 OK |
| **Cluster Maintenance Probe** | Exit code 0 signals safe node eviction | PASS | Exited 0 under 4-node quorum, prevents split-brain |
| **Client Checksum Verification** | Built-in `mcli checksum verify` validation | PASS | Audits bitrot/checksum directly via client |
| **Restored Web Console** | Full-featured UI without enterprise license restrictions | PASS | Responding on port 9002 (HTTP 200 OK) |
