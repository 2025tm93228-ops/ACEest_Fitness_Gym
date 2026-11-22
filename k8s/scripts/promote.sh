#!/usr/bin/env bash
# Promote a candidate to receive full production traffic.
#   ./promote.sh bluegreen   - cut the Service over to GREEN
#   ./promote.sh canary      - raise canary weight to 100
set -euo pipefail
NS=aceest
case "${1:-}" in
  bluegreen)
    kubectl patch svc aceest-bluegreen-svc -n $NS \
      -p '{"spec":{"selector":{"app":"aceest-fitness","variant":"green"}}}'
    kubectl annotate svc aceest-bluegreen-svc -n $NS aceest.io/live-variant=green --overwrite
    echo "GREEN is now live" ;;
  canary)
    kubectl annotate ingress aceest-canary-weighted -n $NS \
      nginx.ingress.kubernetes.io/canary-weight=100 --overwrite
    echo "canary weight = 100" ;;
  *) echo "usage: $0 bluegreen|canary"; exit 1 ;;
esac
