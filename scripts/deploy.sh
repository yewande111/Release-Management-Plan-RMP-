#!/usr/bin/env bash
# deploy.sh — Build images, push to ACR, deploy to AKS via Helm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_ROOT/infrastructure/terraform"
HELM_DIR="$PROJECT_ROOT/infrastructure/helm"
NAMESPACE="${NAMESPACE:-recipe-app}"
TARGET_SLOT="${1:-green}"  # Pass "blue" or "green" as argument

echo "============================================"
echo "  Recipe App — Deploy (slot: $TARGET_SLOT)"
echo "============================================"

# --- Get Terraform outputs ---
cd "$TF_DIR"
ACR_NAME=$(terraform output -raw acr_name)
ACR_SERVER=$(terraform output -raw acr_login_server)
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo 'latest')}"

echo "ACR: $ACR_SERVER"
echo "Tag: $IMAGE_TAG"
echo "Slot: $TARGET_SLOT"
echo ""

# --- Login to ACR ---
echo "Logging in to ACR..."
az acr login --name "$ACR_NAME"

# --- Build and push frontend ---
echo ""
echo "Building Frontend..."
cd "$PROJECT_ROOT/services/frontend"
docker build -t "$ACR_SERVER/recipe-frontend:$IMAGE_TAG" -t "$ACR_SERVER/recipe-frontend:latest" .
docker push "$ACR_SERVER/recipe-frontend:$IMAGE_TAG"
docker push "$ACR_SERVER/recipe-frontend:latest"

# --- Build and push backend ---
echo ""
echo "Building Backend..."
cd "$PROJECT_ROOT/services/backend"
docker build -t "$ACR_SERVER/recipe-backend:$IMAGE_TAG" -t "$ACR_SERVER/recipe-backend:latest" .
docker push "$ACR_SERVER/recipe-backend:$IMAGE_TAG"
docker push "$ACR_SERVER/recipe-backend:latest"

# --- Deploy to AKS ---
cd "$PROJECT_ROOT"
echo ""
echo "Creating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Deploying MongoDB..."
helm upgrade --install recipe-mongodb "$HELM_DIR/mongodb" \
  --namespace "$NAMESPACE" \
  --wait --timeout 5m

echo ""
echo "Deploying Backend (slot: $TARGET_SLOT)..."
helm upgrade --install recipe-backend "$HELM_DIR/backend" \
  --namespace "$NAMESPACE" \
  --set image.repository="$ACR_SERVER/recipe-backend" \
  --set image.tag="$IMAGE_TAG" \
  --set deployment.slot="$TARGET_SLOT" \
  --wait --timeout 5m

echo ""
echo "Deploying Frontend (slot: $TARGET_SLOT)..."
helm upgrade --install recipe-frontend "$HELM_DIR/frontend" \
  --namespace "$NAMESPACE" \
  --set image.repository="$ACR_SERVER/recipe-frontend" \
  --set image.tag="$IMAGE_TAG" \
  --set deployment.slot="$TARGET_SLOT" \
  --wait --timeout 5m

# --- Switch traffic ---
echo ""
echo "Switching traffic to slot: $TARGET_SLOT..."
kubectl patch svc recipe-frontend -n "$NAMESPACE" \
  -p "{\"spec\":{\"selector\":{\"slot\":\"$TARGET_SLOT\"}}}"
kubectl patch svc recipe-backend -n "$NAMESPACE" \
  -p "{\"spec\":{\"selector\":{\"slot\":\"$TARGET_SLOT\"}}}"

echo ""
echo "============================================"
echo "  Deployment Complete!"
echo "============================================"
kubectl get pods -n "$NAMESPACE"
echo ""
FRONTEND_IP=$(kubectl get svc recipe-frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
echo "  Frontend URL: http://$FRONTEND_IP"
echo "  Active Slot:  $TARGET_SLOT"
echo "============================================"
