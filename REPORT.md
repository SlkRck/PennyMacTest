# PennyMac Technical Exercise Report — EBS Snapshot Cleaner

## 1) Executive Summary
This repository implements a secure, serverless EBS snapshot lifecycle solution using AWS Lambda, deployed with modular Terraform. The Lambda enumerates account-owned EC2 snapshots, identifies snapshots older than a configurable retention window (default 365 days), and deletes eligible snapshots. Safety controls are built in: the solution defaults to DRY_RUN mode and can require an explicit tag gate (only tagged snapshots are eligible). The intended runtime model places Lambda in private subnets with interface VPC endpoints for EC2/STS/CloudWatch Logs to avoid NAT requirements. Optional hardening includes KMS encryption for Lambda environment variables and CloudWatch log groups.

---

## 2) Requirements Mapping (Prompt → Code)

| Prompt Requirement | Where Implemented | Notes |
|---|---|---|
| VPC + at least one private subnet | `terraform/modules/network/` | VPC + private subnets + routing + SGs |
| IAM role w/ correct permissions | `terraform/modules/lambda_*` | Lambda trust policy + least-privilege permissions |
| (Bonus) Schedule trigger | `terraform/modules/schedule/` | EventBridge rule + target |
| Lambda lists snapshots | `lambda/` (handler) | Uses boto3 EC2 client; typically `OwnerIds=["self"]` |
| Filter snapshots older than 1 year | `lambda/` (handler) | Cutoff computed from snapshot StartTime |
| Delete eligible snapshots | `lambda/` (handler) | `DeleteSnapshot` per eligible snapshot |
| Logging + error handling | `lambda/` (handler) | Logs actions; catches AWS API errors |
| Deployment instructions | `README.md` + Section 6 | Terraform local state; optional remote backend |
| Monitoring guidance | `README.md` + Section 7 | CloudWatch Logs, Lambda metrics |
| Diagram included | `diagrams/architecture.mmd` + `diagrams/architecture.png` | Mermaid source + static export |

---

## 3) Architecture Walkthrough

### Components
- **EventBridge (optional):** triggers Lambda on a schedule (e.g., daily).
- **Lambda (Python):** executes snapshot discovery/filter/delete logic.
- **VPC + Private Subnets:** isolates Lambda from public networks.
- **Interface VPC Endpoints:** EC2, STS, and CloudWatch Logs endpoints enable private API access without NAT.
- **IAM Role:** grants only the permissions needed to describe/delete snapshots and write logs.
- **CloudWatch Logs:** receives run output, including eligibility and deletion actions.
- **KMS (optional hardening):** encrypts Lambda env vars and/or log groups.

### Data Flow
1. EventBridge invokes the Lambda (or the function is invoked manually).
2. Lambda queries EC2 snapshots via `DescribeSnapshots`.
3. Lambda computes a cutoff timestamp: `now_utc - retention_window`.
4. Lambda filters snapshots older than the cutoff, and optionally checks tag gating.
5. Lambda logs each eligible snapshot and either deletes it (when DRY_RUN=false) or logs “would delete” (DRY_RUN=true).
6. Logs are emitted to CloudWatch Logs; Lambda metrics are available via CloudWatch Metrics.

Diagram sources:
- `diagrams/architecture.mmd` (Mermaid)
- `diagrams/architecture.png` (static)

---

## 4) Security Design and Least Privilege

### Least privilege IAM
The Lambda role is scoped to the minimum viable permissions:
- EC2: `DescribeSnapshots`, `DeleteSnapshot` (and related describe actions if required)
- Logs: permissions to write log events and manage log streams (and create log group if Terraform does not pre-create it)
- Optional: KMS permissions if using a customer-managed key for env vars/logs

### Safety controls
- **DRY_RUN (default):** no snapshots are deleted; actions are logged.
- **Tag gating (recommended):** only snapshots with a specific tag are eligible (e.g., `ManagedBy=SnapshotCleaner`).
- **Account scoping:** snapshot enumeration is scoped to account-owned snapshots to avoid cross-account actions.

### Network hardening
- Lambda runs in private subnets.
- Interface endpoints are used to avoid NAT and reduce exposure.
- Security groups restrict traffic to endpoint ENIs as needed.

---

## 5) Lambda Runtime Behavior

### Snapshot selection logic
- Enumerates snapshots (typically `OwnerIds=["self"]`).
- Uses each snapshot’s `StartTime` to compute its age.
- Determines eligibility based on retention threshold.

### Deletion behavior
- DRY_RUN=true: logs eligible snapshots; does not delete.
- DRY_RUN=false: attempts to delete eligible snapshots; logs success/failure.

### Error handling
- AWS API calls are wrapped with basic error handling.
- Failures are logged; processing continues (best-effort cleanup without halting on one failure).

---

## 6) Deployment & Configuration

### Local state (default)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform init
terraform plan
terraform apply