#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Rollback mechanisms - one per strategy. Each reverts to the last stable
# version, which is the requirement "ensure rollback mechanisms are in place
# to revert to the last stable version in case of deployment failure".
#
#   ./rollback.sh rolling     - kubectl rollout undo (previous ReplicaSet)
#   ./rollback.sh bluegreen   - flip the Service selector back to blue
#   ./rollback.sh canary      - set canary weight to 0
#   ./rollback.sh ab          - remove the experiment ingress
#   ./rollback.sh shadow      - drop the mirror annotation
# ---------------------------------------------------------------------------
set -euo pipefail
NS=aceest
say() { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }

case "${1:-}" in
  rolling)
    say "Rolling back the rolling-update Deployment to its previous revision"
    kubectl rollout history deployment/aceest-rolling -n $NS
    kubectl rollout undo deployment/aceest-rolling -n $NS
    kubectl rollout status deployment/aceest-rolling -n $NS --timeout=120s
    ;;
  bluegreen)
    say "Switching the live Service back to BLUE (last stable)"
    kubectl patch svc aceest-bluegreen-svc -n $NS \
      -p '{"spec":{"selector":{"app":"aceest-fitness","variant":"blue"}}}'
    kubectl annotate svc aceest-bluegreen-svc -n $NS aceest.io/live-variant=blue --overwrite
    ;;
  canary)
    say "Withdrawing the canary - weight to 0, all traffic back to stable"
    kubectl annotate ingress aceest-canary-weighted -n $NS \
      nginx.ingress.kubernetes.io/canary-weight=0 --overwrite
    ;;
  ab)
    say "Ending the A/B experiment - all traffic to variant A"
    kubectl delete ingress aceest-ab-experiment -n $NS --ignore-not-found
    ;;
  shadow)
    say "Disabling traffic mirroring"
    kubectl annotate ingress aceest-shadow-ingress -n $NS \
      nginx.ingress.kubernetes.io/mirror-target- --overwrite 2>/dev/null || true
    ;;
  *) echo "usage: $0 rolling|bluegreen|canary|ab|shadow"; exit 1 ;;
esac
say "done"
