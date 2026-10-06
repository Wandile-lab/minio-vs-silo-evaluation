# DEV-908: MinIO Distributed Mode — Resilience, Healing, and Expansion

## Topology & Erasure Coding Configuration
- **Cluster Architecture**: 4 nodes (`minio-d1` through `minio-d4`), 1 drive per node (4 drives total).
- **Network / Transport**: Internal Docker bridge (`migration-net`) over mutual TLS with SAN hostnames (`minio-d1..d8`, `localhost`).
- **Erasure Set Geometry**: 
  - Stripe Size: 4
  - Erasure Sets: 1
  - Parity Ratio: **EC:2** (2 data blocks, 2 parity blocks per stripe)
- **Quorum Rules**:
  - Read Quorum: $N - P = 4 - 2 = \mathbf{2}$ drives online (Tolerance: up to 2 nodes down).
  - Write Quorum: $(N / 2) + 1 = (4 / 2) + 1 = \mathbf{3}$ drives online (Tolerance: 1 node down).

## Failure Scenarios & Quorum Matrix

| Scenario | Online Nodes | Read Availability | Write Availability | Observed Behavior | Data Loss |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Baseline** | 4 / 4 | **PASS** | **PASS** | Full cluster operation; EC:2 parity active | None |
| **1 Node Down** (`minio-d4`) | 3 / 4 | **PASS** | **PASS** | Within write quorum ($3 \ge 3$) and read quorum ($3 \ge 2$) | None |
| **2 Nodes Down** (`minio-d3`, `d4`) | 2 / 4 | **PASS** | **FAIL** | Read quorum intact ($2 \ge 2$), write quorum lost ($2 < 3$). Cluster safely degrades to read-only | None |
| **3 Nodes Down** (`d2`, `d3`, `d4`)| 1 / 4 | **FAIL** | **FAIL** | Below read quorum ($1 < 2$). Cluster fails closed to prevent serving incomplete/corrupted stripes | None |
| **Drive Volume Wipe** (`d4`) | 4 / 4 | **PASS** | **PASS** | Direct filesystem wipe on `d4/dist-resilience-bucket`; healed via `mc admin heal -r` in 5s (22/22 objects restored) | None |
| **Rolling Restart** | 3/4 $\to$ 4/4 | **PASS** | **PASS** | Sequential restart gated by healthchecks (`minio/health/live`); zero client downtime | None |

## Expansion & Decommissioning
- **Pool Expansion**: Added Server Pool 2 (`https://minio-d{5...8}:9000/data`), expanding cluster from 4 drives to 8 drives across 2 erasure sets without disruption. Existing bucket data was immediately readable post-expansion.
- **Decommissioning**: Successfully initiated and verified completion of pool drain/decommission on Pool 2 via `mcli admin decommission`.

## Compose Safety Checks
- **Duplicate Volume Protection**: Each drive contains format metadata (`.minio.sys/format.json`) specifying a unique Disk UUID bound to the cluster deployment ID. Mounting the same underlying volume across multiple instances is prevented to avoid split-brain filesystem corruption.

## Evidence Artifacts
- `docs/04-minio-distributed-mode/evidence/cluster-admin-info.txt`
- `docs/04-minio-distributed-mode/evidence/resource-usage.txt`
- `docs/04-minio-distributed-mode/evidence/failure-healing-test.txt`
- `docs/04-minio-distributed-mode/evidence/rolling-restart.txt`
- `docs/04-minio-distributed-mode/evidence/duplicate-volume-test.txt`
- `docs/04-minio-distributed-mode/evidence/pool-expansion-decommission.txt`
