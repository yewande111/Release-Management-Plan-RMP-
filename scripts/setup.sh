#!/usr/bin/env bash
# setup.sh — One-time setup: provision Azure infrastructure and configure kubectl
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/infrastructure/terraform"

echo "============================================"
echo "  Recipe App — Infrastructure Setup"
echo "============================================"

# --- Check prerequisites ---
for cmd in az terraform helm kubectl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is not installed." >&2
    exit 1
  fi
done

# --- Verify Azure login ---
if ! az account show &>/dev/null; then
  echo "Not logged in to Azure. Running 'az login'..."
  az login
fi

echo ""
echo "Azure subscription:"
az account show --query "{name:name, id:id}" -o table

# --- Terraform init & apply ---
echo ""
echo "Provisioning infrastructure with Terraform..."
cd "$TF_DIR"

if [ ! -f terraform.tfvars ]; then
  echo "No terraform.tfvars found. Copying from example..."
  cp terraform.tfvars.example terraform.tfvars
  echo "Please edit infrastructure/terraform/terraform.tfvars and re-run."
  exit 1
fi

terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan
rm -f tfplan

# --- Get outputs ---
RG=$(terraform output -raw resource_group_name)
AKS=$(terraform output -raw aks_cluster_name)
ACR=$(terraform output -raw acr_name)
ACR_SERVER=$(terraform output -raw acr_login_server)

echo ""
echo "Configuring kubectl..."
az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing

echo ""
echo "Verifying cluster connectivity..."
kubectl get nodes

echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo "  Resource Group:  $RG"
echo "  AKS Cluster:     $AKS"
echo "  ACR Registry:    $ACR_SERVER"
echo ""
echo "  Next: Run ./scripts/deploy.sh"
echo "============================================"
