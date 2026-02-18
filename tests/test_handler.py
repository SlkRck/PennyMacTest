import os
from datetime import datetime, timedelta, timezone

import importlib

# Import the handler module
handler = importlib.import_module("lambda.handler")


class FakeEC2:
    def __init__(self):
        self.deleted = []

    def delete_snapshot(self, SnapshotId: str):
        self.deleted.append(SnapshotId)


def _mk_snapshot(snapshot_id: str, age_days: int, tags=None):
    return {
        "SnapshotId": snapshot_id,
        "StartTime": datetime.now(timezone.utc) - timedelta(days=age_days),
        "Tags": tags or [],
    }


def test_dry_run_deletes_nothing(monkeypatch):
    fake = FakeEC2()

    monkeypatch.setattr(handler.boto3, "client", lambda service: fake)
    monkeypatch.setattr(
        handler,
        "_describe_all_snapshots",
        lambda ec2_client, owner: [
            _mk_snapshot("snap-old", 400, [{"Key": "ManagedBy", "Value": "SnapshotCleaner"}]),
            _mk_snapshot("snap-new", 10, [{"Key": "ManagedBy", "Value": "SnapshotCleaner"}]),
        ],
    )

    os.environ["RETENTION_DAYS"] = "365"
    os.environ["DRY_RUN"] = "true"
    os.environ["DELETE_ONLY_TAGGED"] = "true"
    os.environ["DELETE_TAG_KEY"] = "ManagedBy"
    os.environ["DELETE_TAG_VALUE"] = "SnapshotCleaner"

    result = handler.lambda_handler({}, None)

    assert result["eligible"] == 1
    assert fake.deleted == []


def test_tag_gating_only_deletes_tagged(monkeypatch):
    fake = FakeEC2()

    monkeypatch.setattr(handler.boto3, "client", lambda service: fake)
    monkeypatch.setattr(
        handler,
        "_describe_all_snapshots",
        lambda ec2_client, owner: [
            _mk_snapshot("snap-old-tagged", 400, [{"Key": "ManagedBy", "Value": "SnapshotCleaner"}]),
            _mk_snapshot("snap-old-untagged", 400, [{"Key": "Other", "Value": "Nope"}]),
        ],
    )

    os.environ["RETENTION_DAYS"] = "365"
    os.environ["DRY_RUN"] = "false"
    os.environ["DELETE_ONLY_TAGGED"] = "true"
    os.environ["DELETE_TAG_KEY"] = "ManagedBy"
    os.environ["DELETE_TAG_VALUE"] = "SnapshotCleaner"

    result = handler.lambda_handler({}, None)

    assert result["eligible"] == 1
    assert fake.deleted == ["snap-old-tagged"]


def test_missing_tag_config_forces_dry_run(monkeypatch):
    fake = FakeEC2()

    monkeypatch.setattr(handler.boto3, "client", lambda service: fake)
    monkeypatch.setattr(
        handler,
        "_describe_all_snapshots",
        lambda ec2_client, owner: [
            _mk_snapshot("snap-old", 400, [{"Key": "ManagedBy", "Value": "SnapshotCleaner"}]),
        ],
    )

    os.environ["RETENTION_DAYS"] = "365"
    os.environ["DRY_RUN"] = "false"
    os.environ["DELETE_ONLY_TAGGED"] = "true"
    os.environ.pop("DELETE_TAG_KEY", None)
    os.environ.pop("DELETE_TAG_VALUE", None)

    result = handler.lambda_handler({}, None)

    assert result["dry_run"] is True
    assert fake.deleted == []
