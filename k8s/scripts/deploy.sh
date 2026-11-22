#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Deploy one (or all) of the five deployment strategies to the cluster.
#   ./deploy.sh rolling | bluegreen | canary | ab | shadow | all
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."
NS=aceest
S="${1:-all}"

say() { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }

kubectl apply -f 00-base/namespace.yaml

case "$S" in
  rolling)   kubectl apply -f 01-rolling-update/ ;;
  bluegreen) kubectl apply -f 02-blue-green/ ;;
  canary)    kubectl apply -f 03-canary/ ;;
  ab)        kubectl apply -f 04-ab-testing/ ;;
  shadow)    kubectl apply -f 05-shadow/ ;;
  all)
    for d in 01-rolling-update 02-blue-green 03-canary 04-ab-testing 05-shadow; do
      say "applying $d"; kubectl apply -f "$d/"
    done ;;
  *) echo "usage: $0 rolling|bluegreen|canary|ab|shadow|all"; exit 1 ;;
esac

say "waiting for rollouts"
for d in $(kubectl get deploy -n $NS -o name 2>/dev/null); do
  kubectl rollout status "$d" -n $NS --timeout=180s || true
done

say "cluster state"
kubectl get deploy,svc,ingress -n $NS
