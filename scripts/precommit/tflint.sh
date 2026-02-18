#!/usr/bin/env bash
set -euo pipefail
if ! command -v tflint >/dev/null 2>&1; then
  echo "SKIP: tflint not found (install from https://github.com/terraform-linters/tflint)"
  exit 0
fi
tflint --recursive terraform
