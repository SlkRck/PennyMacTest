# 5-minute architecture walkthrough script

**0:00–1:00 — Overview**  
This deploys a Lambda in a private subnet that deletes EBS snapshots older than a configurable retention window. The system is fully IaC via Terraform and can run on a schedule via EventBridge.

**1:00–2:00 — Networking**  
The Lambda has no public exposure. Instead of using a NAT gateway, it uses interface VPC endpoints so it can call the EC2, STS, and CloudWatch Logs APIs privately.

**2:00–3:00 — Security controls**  
I encrypt Lambda environment variables and CloudWatch log groups with a customer-managed KMS key. Log retention is explicitly set. Deletions are tag-gated by default and DRY_RUN is enabled until intentionally turned off.

**3:00–4:00 — Terraform quality**  
Terraform is modular (network / lambda / schedule) and all environment values are provided via terraform.tfvars. I included an optional remote backend (S3 + DynamoDB lock) as an example for production state.

**4:00–5:00 — DevSecOps**  
CI runs fmt/validate, then security scanning using tflint, tfsec, and checkov. Optional local pre-commit hooks enforce the same checks before code is pushed.
