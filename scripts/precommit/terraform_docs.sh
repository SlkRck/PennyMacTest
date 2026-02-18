#!/usr/bin/env bash
set -euo pipefail
if ! command -v terraform-docs >/dev/null 2>&1; then
  echo "SKIP: terraform-docs not found (install from https://terraform-docs.io/)"
  exit 0
fi

# Generate/refresh module README.md files.
for m in terraform/modules/*; do
  if [ -d "$m" ]; then
    terraform-docs markdown table "$m" > "$m/README.md"
  fi
done

echo "terraform-docs: updated module READMEs."
