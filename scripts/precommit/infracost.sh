#!/usr/bin/env bash
set -euo pipefail
if ! command -v infracost >/dev/null 2>&1; then
  echo "SKIP: infracost not found (install from https://www.infracost.io/)"
  exit 0
fi
if [ -z "${INFRACOST_API_KEY:-}" ]; then
  echo "SKIP: INFRACOST_API_KEY not set (optional)"
  exit 0
fi
# Lightweight local estimate; CI uses the official action.
infracost breakdown --path terraform --format table
