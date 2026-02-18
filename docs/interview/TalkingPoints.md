# Talking points (design decisions)

## Why private subnet + VPC endpoints (no NAT)?
- Lambda only needs AWS control-plane calls (EC2, STS, Logs), so Interface Endpoints provide private connectivity.
- Removes public internet dependency and reduces cost and attack surface.

## How do you prevent accidental deletion?
- Defaults: `DRY_RUN=true` and `DELETE_ONLY_TAGGED=true`.
- Tag key/value required; if missing the function forces dry-run.
- Terraform exposes safe toggles; reviewers can see exactly how deletion is controlled.

## Least-privilege IAM
- Lambda role grants only: `ec2:DescribeSnapshots`, `ec2:DeleteSnapshot`, plus minimal CloudWatch Logs permissions.
- In tag-gated mode, you can further constrain deletes via `aws:ResourceTag/<key>`.

## Why modular Terraform?
- Clear separation of concerns: network, lambda, schedule.
- Reusable modules; easier review; less blast-radius for changes.

## Why optional remote backend?
- Backends can't use normal variables; provided as `backend.tf.example`.
- Local state by default improves reviewer experience; remote backend is production-ready option.

## Why CI scanning tools?
- IaC should be reviewed like application code.
- Early detection of insecure patterns before they ship.
