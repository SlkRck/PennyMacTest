# Executive summary (2 minutes)

This repository delivers a serverless snapshot lifecycle control for EBS snapshots.

- **What it does:** A scheduled AWS Lambda enumerates EBS snapshots, filters those older than a configurable retention window, and deletes eligible snapshots.
- **Safety:** Deletions are **tag-gated by default** and the function defaults to **DRY_RUN=true** until you explicitly enable deletion.
- **Security posture:** Lambda runs in a **private subnet** and reaches AWS APIs through **Interface VPC Endpoints** (no NAT). Logs and environment variables are encrypted using a **customer-managed KMS key**, and CloudWatch log retention is defined.
- **IaC quality:** Infrastructure is modular Terraform with all environment values supplied via `.tfvars`.
- **DevSecOps:** GitHub Actions runs `terraform fmt/validate` plus security scanning (tflint, tfsec, checkov). Optional pre-commit hooks and example OPA guardrails are included.
