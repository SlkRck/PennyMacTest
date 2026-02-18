# OPA / Conftest guardrails (optional)

This repo includes an example **OPA policy** so you can enforce non-negotiable security controls in CI or locally.

Typical production flow:

1. Produce a Terraform plan JSON:

```bash
cd terraform
terraform init
terraform plan -out tfplan
terraform show -json tfplan > tfplan.json
```

2. Run conftest against the plan:

```bash
conftest test tfplan.json -p ../policy
```

> For an interview exercise (no shared AWS creds), CI does **not** require conftest. The policy is included to
> demonstrate how you'd implement IaC guardrails in real delivery.

## Policy intent

- Ensure Lambda and CloudWatch logs are encrypted with a customer-managed KMS key.
- Ensure log retention is set.
- Encourage safe deletion mode (tag-gated deletes) for destructive automation.
