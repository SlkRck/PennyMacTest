#!/usr/bin/env bash
set -euo pipefail
if ! command -v terraform >/dev/null 2>&1; then
  echo "SKIP: terraform not found"
  exit 0
fi
terraform fmt -recursive terraform
