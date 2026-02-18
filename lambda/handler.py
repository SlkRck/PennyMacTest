"""AWS Lambda — Delete EC2 snapshots older than a retention window.

This function:
- Lists EC2 snapshots in-region.
- Filters snapshots older than RETENTION_DAYS.
- Optionally restricts deletions to snapshots that match a required tag.
- Attempts to delete each eligible snapshot.
- Logs actions and handles common API errors.

Environment variables:
- RETENTION_DAYS: int, default 365
- SNAPSHOT_OWNER: string, default 'self' (OwnerIds filter)
- DRY_RUN: 'true'/'false', default 'true' (safer first-run)
- DELETE_ONLY_TAGGED: 'true'/'false', default 'true' (safer first-run)
- DELETE_TAG_KEY: string, required when DELETE_ONLY_TAGGED=true
- DELETE_TAG_VALUE: string, required when DELETE_ONLY_TAGGED=true

Notes:
- In most accounts, describing *all* snapshots is not permitted/desired.
  The default behavior targets snapshots owned by the current account (OwnerIds=['self']).
- If DELETE_ONLY_TAGGED=true but the tag key/value are not set, the function forces DRY_RUN=true.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import boto3
from botocore.exceptions import BotoCoreError, ClientError

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def _get_env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if not value:
        return default
    try:
        return int(value)
    except ValueError:
        LOGGER.warning("Invalid %s=%r; using default=%d", name, value, default)
        return default


def _get_env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "t", "yes", "y"}


def _cutoff_datetime(retention_days: int) -> datetime:
    # Snapshot StartTime is timezone-aware; use UTC-aware timestamps.
    return datetime.now(timezone.utc) - timedelta(days=retention_days)


def _describe_all_snapshots(ec2_client, owner: str) -> List[Dict[str, Any]]:
    """Return all snapshots for the given OwnerIds filter, handling pagination."""
    snapshots: List[Dict[str, Any]] = []

    describe_kwargs: Dict[str, Any] = {"MaxResults": 1000}
    if owner:
        describe_kwargs["OwnerIds"] = [owner]

    paginator = ec2_client.get_paginator("describe_snapshots")
    for page in paginator.paginate(**describe_kwargs):
        snapshots.extend(page.get("Snapshots", []))

    return snapshots


def _should_delete(snapshot: Dict[str, Any], cutoff: datetime) -> bool:
    start_time: Optional[datetime] = snapshot.get("StartTime")
    if not start_time:
        return False
    return start_time < cutoff


def _has_required_tag(snapshot: Dict[str, Any], tag_key: str, tag_value: str) -> bool:
    tags = snapshot.get("Tags") or []
    for t in tags:
        if t.get("Key") == tag_key and t.get("Value") == tag_value:
            return True
    return False


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    retention_days = _get_env_int("RETENTION_DAYS", 365)
    owner = os.getenv("SNAPSHOT_OWNER", "self").strip() or "self"

    # Default to safe behavior for an interview exercise: dry-run + tag gating.
    dry_run = _get_env_bool("DRY_RUN", True)
    delete_only_tagged = _get_env_bool("DELETE_ONLY_TAGGED", True)
    delete_tag_key = os.getenv("DELETE_TAG_KEY", "").strip()
    delete_tag_value = os.getenv("DELETE_TAG_VALUE", "").strip()

    if delete_only_tagged and (not delete_tag_key or not delete_tag_value):
        LOGGER.warning(
            "DELETE_ONLY_TAGGED=true but DELETE_TAG_KEY/DELETE_TAG_VALUE not set; forcing DRY_RUN=true."
        )
        dry_run = True

    cutoff = _cutoff_datetime(retention_days)

    LOGGER.info(
        "Starting snapshot cleanup. retention_days=%d cutoff=%s owner=%s dry_run=%s delete_only_tagged=%s",
        retention_days,
        cutoff.isoformat(),
        owner,
        dry_run,
        delete_only_tagged,
    )

    ec2 = boto3.client("ec2")

    try:
        snapshots = _describe_all_snapshots(ec2, owner)
    except (ClientError, BotoCoreError) as exc:
        LOGGER.exception("Failed to describe snapshots: %s", exc)
        raise

    old_snapshots = [s for s in snapshots if _should_delete(s, cutoff)]

    if delete_only_tagged:
        old_snapshots = [
            s for s in old_snapshots if _has_required_tag(s, delete_tag_key, delete_tag_value)
        ]

    LOGGER.info(
        "Found %d snapshots total; %d eligible for deletion (older than cutoff and tag filter, if enabled).",
        len(snapshots),
        len(old_snapshots),
    )

    deleted: List[str] = []
    failed: List[Dict[str, str]] = []

    for snap in old_snapshots:
        snap_id = snap.get("SnapshotId", "<unknown>")
        start_time = snap.get("StartTime")
        LOGGER.info("Eligible snapshot: %s start_time=%s", snap_id, start_time)

        if dry_run:
            continue

        try:
            ec2.delete_snapshot(SnapshotId=snap_id)
            deleted.append(snap_id)
        except ClientError as exc:
            code = exc.response.get("Error", {}).get("Code", "Unknown")
            msg = exc.response.get("Error", {}).get("Message", str(exc))
            LOGGER.warning("Failed to delete snapshot %s: %s - %s", snap_id, code, msg)
            failed.append({"snapshot_id": snap_id, "error_code": code, "message": msg})
        except BotoCoreError as exc:
            LOGGER.warning("BotoCoreError deleting snapshot %s: %s", snap_id, exc)
            failed.append({"snapshot_id": snap_id, "error_code": "BotoCoreError", "message": str(exc)})

    result = {
        "retention_days": retention_days,
        "cutoff": cutoff.isoformat(),
        "owner": owner,
        "dry_run": dry_run,
        "delete_only_tagged": delete_only_tagged,
        "delete_tag_key": delete_tag_key,
        "delete_tag_value": delete_tag_value,
        "total_snapshots": len(snapshots),
        "eligible": len(old_snapshots),
        "deleted": deleted,
        "failed": failed,
    }

    LOGGER.info("Snapshot cleanup complete: %s", result)
    return result
