# PennyMac Technical Exercise — EBS Snapshot Cleaner

## Synopsis
A secure, serverless **EBS snapshot lifecycle** solution:
- Runs an AWS Lambda on a schedule (EventBridge).
- Finds snapshots older than a retention window.
- Deletes eligible snapshots (defaults to **safe mode**: tag-gated + dry-run).

## Architecture
- **Lambda** in a **private subnet** (no public exposure)
- **Interface VPC Endpoints** for EC2 / STS / CloudWatch Logs (no NAT required)
- **KMS** for encrypting Lambda env vars and CloudWatch log groups
- **Terraform** (modular, `.tfvars`-driven)

Diagram sources:
- `diagrams/architecture.mmd` (Mermaid)
- `diagrams/architecture.png` (static)

## Repository layout
- `terraform/` — modular Terraform (network / lambda / schedule)
- `lambda/` — Python Lambda handler
- `scripts/` — helper scripts (incl. GitHub repo bootstrap)
- `docs/interview/` — reviewer Q&A, talking points, walkthrough scripts
- `policy/` — optional OPA / Conftest guardrails (example)
- `tests/` — unit tests for the Lambda logic

## Requirements
- Terraform >= 1.6
- AWS credentials (for `terraform apply`)
- Optional local tooling:
  - `tflint`, `tfsec`, `checkov`
  - `pre-commit`
  - `terraform-docs`
  - `infracost` (requires `INFRACOST_API_KEY`)
  - `conftest` (OPA)

## Quickstart (local state)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform init
terraform apply
```

### Safe first run (recommended)
In `terraform/terraform.tfvars` keep:
- `dry_run = true`
- `delete_only_tagged = true`

Tag snapshots you intend to allow the cleaner to delete:
- `ManagedBy=SnapshotCleaner` (default in example)

Then re-apply with `dry_run = false` once you confirm eligibility output in logs.

## Remote backend (optional)
For reviewer friendliness, this repo defaults to **local state**.

To enable S3 + DynamoDB locking:
```bash
cd terraform
cp backend.tf.example backend.tf
# edit backend.tf with your bucket/table/key/region
terraform init -reconfigure
```

> Terraform backends cannot take normal variables; this is why it’s provided as an example file.

## CI pipeline (DevSecOps)
GitHub Actions workflows:
- `.github/workflows/terraform-security.yml` — fmt/validate + tflint/tfsec/checkov scanning
- `.github/workflows/python-tests.yml` — pytest unit tests for Lambda
- `.github/workflows/infracost.yml` — optional cost estimate on PRs (runs only if `INFRACOST_API_KEY` secret exists)
- `.github/workflows/terraform-docs.yml` — optional docs generation (non-blocking)

## Pre-commit (local enforcement)
This repo includes `.pre-commit-config.yaml`.

Enable it:
```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

The hooks call scripts under `scripts/precommit/` and will **skip** gracefully if optional tools are not installed.

## Terraform-docs (module documentation)
If you install `terraform-docs`, you can generate module docs locally:
```bash
scripts/precommit/terraform_docs.sh
```

## Infracost (optional)
If you have an `INFRACOST_API_KEY`:
```bash
export INFRACOST_API_KEY=...
scripts/precommit/infracost.sh
```

CI will also run Infracost on PRs when the GitHub secret is present.

## OPA / Conftest (optional)
See `policy/README.md` for how to generate a plan JSON and evaluate it with Conftest.

## Unit tests
```bash
pip install -r requirements-dev.txt
pytest -q
```

