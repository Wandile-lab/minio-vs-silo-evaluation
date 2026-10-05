# DEV-907: MinIO Feature Validation (Single Node Baseline)

## Goal
Execute a comprehensive evaluation of the S3 API surface, SDK interoperability, IAM/policy enforcement, versioning edge cases, WORM object locking, lifecycle management, and observability metrics on the pinned MinIO baseline (`RELEASE.2026-08-04T00-00-00Z`).

## Test Results & Capability Matrix

| Feature / Scenario | Test Method / Client | Expected Result | Observed Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Core S3 API** | `aws-cli` | Bucket creation, PUT, GET, Head, and Range Read (0-9) | Payload retrieved, range read exact 10 bytes | **PASS** |
| **SDK Interoperability** | Python `boto3` v1.34+ | Custom metadata, object tags, and presigned GET URL fetch | Metadata and tags persisted; presigned URL valid | **PASS** |
| **IAM Policy Boundaries** | Service Account via `mcli` | Read allowed; PUT blocked with permission error | Read succeeded; write blocked with `Insufficient permissions` | **PASS** |
| **Anonymous Access** | `curl` | Unauthenticated GET allowed on `/public` prefix | Public content retrieved over TLS without headers | **PASS** |
| **WORM Compliance Retention**| `mcli rm --version-id` | Purge of compliance locked version rejected | Rejected: `is WORM protected and cannot be overwritten` | **PASS** |
| **WORM Legal Hold** | `mcli rm --version-id` | Purge blocked under active legal hold | Rejected: WORM protection enforced even by root | **PASS** |
| **Versioning Edge Cases** | `mcli` | Delete marker insertion hides object; suspend/enable preserves stack | Delete marker hid object; version state transitions clean | **PASS** |
| **Lifecycle Expiration** | `mcli ilm` | Noncurrent expiry and delete marker cleanup rule configured | Rule added and listed with ID `db1rkosheeoc72qsqd2g` | **PASS** |
| **Observability (Metrics)** | `curl` | Prometheus metrics emitted on `/minio/v2/metrics/cluster` | HTTP 200, valid Prometheus metrics stream captured | **PASS** |
| **Observability (Trace)** | `mcli admin trace` | Real-time HTTP wire trace of S3 API operations | Captured live incoming requests and status codes | **PASS** |

## Community Release Limitations Observed
- Built-in web console features are restricted relative to enterprise configurations; administrative and user provisioning is executed via CLI/API.
- Direct root bucket enumeration requires `s3:ListAllMyBuckets`; prefix-scoped policies require explicit path traversal permissions.

## Evidence Artifacts
- `docs/03-minio-feature-validation/evidence/awscli-core-s3.txt`
- `docs/03-minio-feature-validation/evidence/boto3-sdk-test.txt`
- `docs/03-minio-feature-validation/evidence/iam-policy-access.txt`
- `docs/03-minio-feature-validation/evidence/versioning-worm-locks.txt`
- `docs/03-minio-feature-validation/evidence/lifecycle-observability.txt`
- `docs/03-minio-feature-validation/evidence/raw_metrics.txt`
