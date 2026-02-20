# Explanations

## “Why no NAT Gateway?”
Because the Lambda only needs AWS API access, interface endpoints (EC2/Logs/STS) are a tighter, cheaper pattern that keeps traffic on the AWS network.

## “How do you avoid deleting the wrong snapshots?”
Deletions are tag-gated by default, and the function defaults to DRY_RUN. If the required tag settings are missing, it forces DRY_RUN to prevent accidental deletes.

## “How would you scale this across many accounts?”
Use an Organizations pattern: central scheduler + cross-account role assumption, or deploy the same module per account with a workspace/pipeline.

## “What about monitoring?”
CloudWatch Logs capture each eligible snapshot and each delete attempt. In a production version I'd add metrics (deleted_count, failed_count) + alarms.

## “What if snapshots are in use?”
The Lambda handles API failures per-snapshot (e.g., `InvalidSnapshot.InUse`) and continues processing, returning a summary with failures.
