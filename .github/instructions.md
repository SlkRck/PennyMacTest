# Instructions — pennymac-snapshot-cleaner

Purpose
- Help contributors understand the repository quickly and make safe, minimal changes.

Big picture
- This small project provides an AWS Lambda that deletes EC2 snapshots older than a retention window.
- Core behavior is implemented in `lambda/handler.py`: describe snapshots (paginated), filter by age and optional tag, and delete each snapshot.
- Safety-first defaults: `DRY_RUN=true` and `DELETE_ONLY_TAGGED=true`. If tag key/value are missing, `DRY_RUN` is forced true.

Key files to read first
- `lambda/handler.py` — main logic and environment-driven behavior (RETENTION_DAYS, SNAPSHOT_OWNER, DRY_RUN, DELETE_ONLY_TAGGED, DELETE_TAG_KEY, DELETE_TAG_VALUE).

Important implementation details & patterns
- Uses `boto3.client('ec2')` and paginators (`get_paginator('describe_snapshots')`) with `MaxResults=1000`.
- Snapshot ownership is filtered via `OwnerIds=['self']` by default — the function does not enumerate all account snapshots unless configured.
- Time comparisons use timezone-aware UTC datetimes: `StartTime` compared against `datetime.now(timezone.utc) - timedelta(days=retention)`.
- Error handling distinguishes `botocore.exceptions.ClientError` and `BotoCoreError` for logging and per-snapshot failure records.

Local dev / run guidance
- This repo has no framework glue files (SAM/Serverless) checked in. To run the handler locally, run Python from repo root and call `lambda/handler.py`'s `lambda_handler` directly. Example:

```bash
# set safe env for a dry run
export RETENTION_DAYS=365
export DRY_RUN=true
python -c "from lambda.handler import lambda_handler; print(lambda_handler({}, None))"
```

- On Windows PowerShell, use `$env:RETENTION_DAYS = '365'` and `$env:DRY_RUN='true'` before running Python.
- Real AWS calls require credentials and region (via `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, or default credentials chain).

Testing & mocking
- There are no unit tests in the repo. Prefer mocking `boto3` in tests using `botocore.stub.Stubber` or the `moto` library to simulate EC2 responses.
- Key behaviors to assert in tests:
  - Pagination handling in `_describe_all_snapshots` (multiple pages)
  - Correct cutoff computation and timezone-aware comparisons
  - Tag filtering when `DELETE_ONLY_TAGGED` is enabled
  - Safe defaults: `DRY_RUN` true when required tag missing

Dependencies and environment
- Runtime expects `boto3` and `botocore`. Add them to `requirements.txt` if creating one:
  - boto3
  - mypy-boto3-boto3 (optional typing)

Project conventions
- Keep changes minimal and focused; maintain the safety-first defaults unless explicitly changing behavior.
- Use explicit exception handling for AWS API calls (follow the existing `ClientError` / `BotoCoreError` pattern).
- When adding code that makes AWS calls, prefer injecting or mocking the `boto3` client in tests rather than making real API calls.

PR and review tips for AI agents
- Do not remove or weaken dry-run / tag gating without explicit human approval — these are deliberate safety mechanisms.
- When modifying pagination or API parameters, include a short comment explaining the choice (e.g., `MaxResults=1000` chosen to reduce API round-trips).

If something is unclear
- Ask the human reviewer to provide missing context: intended deploy method (SAM/Serverless/CloudFormation), CI commands, or additional files to add (tests, requirements).

End of file
