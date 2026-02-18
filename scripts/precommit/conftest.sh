#!/usr/bin/env bash
set -euo pipefail
if ! command -v conftest >/dev/null 2>&1; then
  echo "SKIP: conftest not found (install from https://www.conftest.dev/)"
  exit 0
fi
conftest test terraform -p policy
