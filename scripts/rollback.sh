#!/usr/bin/env bash
# rollback.sh — Switch traffic back to the previous deployment slot
set -euo pipefail

NAMESPACE="${NAMESPACE:-recipe-app}"

echo "============================================"
echo "  Recipe App — Rollback"
echo "============================================"

# Detect current slot
CURRENT_SLOT=$(kubectl get svc recipe-frontend -n "$NAMESPACE" -o jsonpath='{.spec.selector.slot}' 2>/dev/null || echo "unknown")

if [ "$CURRENT_SLOT" == "green" ]; then
  ROLLBACK_SLOT="blue"
elif [ "$CURRENT_SLOT" == "blue" ]; then
  ROLLBACK_SLOT="green"
else
  echo "ERROR: Cannot determine current slot. Current: $CURRENT_SLOT" >&2
  exit 1
fi

echo "Current slot: $CURRENT_SLOT"
echo "Rolling back to: $ROLLBACK_SLOT"
echo ""

# Verify rollback slot pods exist
READY_PODS=$(kubectl get pods -n "$NAMESPACE" -l "slot=$ROLLBACK_SLOT" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$READY_PODS" -eq 0 ]; then
  echo "ERROR: No running pods found for slot '$ROLLBACK_SLOT'. Cannot rollback." >&2
  exit 1
fi

echo "Found $READY_PODS running pod(s) on slot $ROLLBACK_SLOT"
echo ""

# Switch traffic
kubectl patch svc recipe-frontend -n "$NAMESPACE" \
  -p "{\"spec\":{\"selector\":{\"slot\":\"$ROLLBACK_SLOT\"}}}"
kubectl patch svc recipe-backend -n "$NAMESPACE" \
  -p "{\"spec\":{\"selector\":{\"slot\":\"$ROLLBACK_SLOT\"}}}"

echo ""
echo "============================================"
echo "  Rollback Complete!"
echo "============================================"
echo "  Traffic switched: $CURRENT_SLOT → $ROLLBACK_SLOT"
echo "============================================"
