#!/usr/bin/env bash
# destroy.sh — Tear down all Azure infrastructure
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(dirname "$SCRIPT_DIR")/infrastructure/terraform"

echo "============================================"
echo "  Recipe App — Destroy Infrastructure"
echo "============================================"
echo ""
echo "WARNING: This will destroy ALL provisioned resources."
read -rp "Type 'DESTROY' to confirm: " CONFIRM

if [ "$CONFIRM" != "DESTROY" ]; then
  echo "Aborted."
  exit 0
fi

cd "$TF_DIR"
terraform init
terraform destroy -auto-approve

echo ""
echo "============================================"
echo "  Infrastructure Destroyed"
echo "============================================"
