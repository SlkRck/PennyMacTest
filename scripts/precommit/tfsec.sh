#!/usr/bin/env bash
set -euo pipefail
if ! command -v tfsec >/dev/null 2>&1; then
  echo "SKIP: tfsec not found (install from https://github.com/aquasecurity/tfsec)"
  exit 0
fi
tfsec terraform
