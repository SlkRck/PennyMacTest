#!/usr/bin/env bash
set -euo pipefail
if ! command -v terraform >/dev/null 2>&1; then
  echo "SKIP: terraform not found"
  exit 0
fi
pushd terraform >/dev/null
terraform init -backend=false -input=false >/dev/null
terraform validate
popd >/dev/null
