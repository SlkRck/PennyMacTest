#!/usr/bin/env bash
set -euo pipefail
if ! command -v checkov >/dev/null 2>&1; then
  echo "SKIP: checkov not found (pip install checkov)"
  exit 0
fi
checkov -d terraform
