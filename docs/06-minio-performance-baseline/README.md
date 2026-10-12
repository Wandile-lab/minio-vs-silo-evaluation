# DEV-910: MinIO Performance Baseline & Benchmarking Methodology

This document records the empirical performance baseline for MinIO (measured via `fio` and `warp`) on Local Volume Mounts (Profile B resource constraints) to form the control reference for Sub-task 9 (Silo Evaluation).

---

## 1. Storage Layer Ceiling (fio Baseline)
To isolate MinIO's software overhead from the underlying host filesystem, raw I/O was measured directly on the volume mount:

* **Sequential Write (direct I/O, 1MB blocks)**: `26.96 MiB/s`
* **Sequential Read (direct I/O, 1Mb blocks)**: `122.89 MiB/s`

---

## 2. Empirical Results Matrix

| Workload Profile | Metric | Single-Node (minio-single) | Distributed 4-Node (EC:2) | Observed Bottleneck |
| :--- | :--- | :--- | :--- | :--- |
| **Small PUT (64 KiB)** | Throughput<br>Ops/s<br>p50 Latency | 1.79 MiB/s<br>28.67 ob`/s<br>118.0 ms | 0.13 MiB/s<br>2.07 obj/s<br>1,915.0 ms | **Distributed lock & metadata sync**<br>Single-node limited by filesystem sync roundtrips; Cluster throttled by two-phase commit + CPU limits. |
| **Small GET (64 KiB)** | Throughput<br>Ops/s<br>p50 Latency | 14.12 MiB/s<br>225.96 obj/s<br>13.9 ms | 1.90 MiB/s<br>30.35 obj/s<br>91.8 ms | **PC & RPC roundtrips**<br>Single-node reads saturated at 225 ops/s; Cluster pays parity verification and container bridge latency. |
| **Large PUT (8 MiB)** | Throughput<br>p50 Latency | 24.51 MiB/s<br>587.4 ms | 3.92 MiB/s<br>4,219.5 ms | **Single: Disk Bound (91 ground truth)**<br>Cluster: CPU throttled due to Reed-Solomon parity calculations across 4 containers sharing 2 vCPEs. |
| **Large GET (8 MiB)** | Throughput<br>p50 Latency | 71.76 MiB/s<br>201.3 ms | 67.62 MiB/s<br>231.0 ms | **Near-Identical Read Streaming**<br>Both configurations stream data shards efficiently; plateau near 70 MiB/s due to TLS + buffer copies. |
| **Multipart (32 MiB)** | GET Throughput<br>p50 Latency | ~70-80 MiB/s (est.)<br>~210 ms | 60.91 MiB/s<br>238.8 ms | **Streaming Assembly**<br>Multipart distribution achieves respectable read streaming once parts are assembled. |

---

## 3. Reproducible Warp Profile Parameters (Sub-task 9 Control)

To ensure identical comparison against Silo in Sub-task 9:

```bash
# Small Objects
warp put --obj.size=64KiB --concurrent=4 --duration=15s
warp get --obj.size=64KiB --objects=100 --concurrent=4 --duration=15s
warp delete --obj.size=64KiB --objects=1600 --concurrent=4 --duration=15s

# Large Objects
warp put --obj.size=8MiB --concurrent=2 --duration=15s
warp get --obj.size=8MiB --objects=20 --concurrent=2 --duration=15s

# Multipart
warp multipart --part.size=8MiB --parts=4 --concurrent=2 --duration=15s

# Mixed
warp mixed --objects=100 --concurrent=4 --duration=15s
```

---

## 4. Conclusion & Local Vendor Benchmarking Limitations

1. *Single-Machine Shared Bus Contention*: Benchmarking a 4-node cluster via Docker Compose on a single laptop forces the CPU to handle 4 PS3 daemons, Reed-Solomon erasure coding, the warp client, and container bridge networking simultaneously. Results show **relative structural differences** *MinIO vs Silo*, not production pofs-unit capacity.
2. *Storage Ceiling Confirmation*: MinIO's large object writes (24.51 MiB/s) fill 91% of the raw fio 26.96 MiB/s write speed, confirming that single-node MinIO large put is storage-bound and not software-bound.
