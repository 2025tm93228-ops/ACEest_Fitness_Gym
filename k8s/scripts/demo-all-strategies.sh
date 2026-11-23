#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Demonstrates and PROVES all five deployment strategies plus rollback.
# Every request is issued from a pod inside the cluster, so the results do not
# depend on host networking, port-forwarding or NodePort reachability.
#
#   ./demo-all-strategies.sh
# ---------------------------------------------------------------------------
set -uo pipefail
NS=aceest
BOX=curlbox
ING=ingress-nginx-controller.ingress-nginx.svc.cluster.local

hdr() { printf '\n\033[1;36m════════ %s ════════\033[0m\n' "$*"; }
sub() { printf '\033[1;33m-- %s\033[0m\n' "$*"; }

cget()  { kubectl exec -n $NS $BOX -- curl -s --max-time 5 "$1" 2>/dev/null; }
# curl through the ingress controller with an explicit Host header
cing()  { kubectl exec -n $NS $BOX -- curl -s --max-time 5 -H "Host: $1" "http://$ING$2" 2>/dev/null; }
cingh() { kubectl exec -n $NS $BOX -- curl -s --max-time 5 -H "Host: $1" -H "$3" "http://$ING$2" 2>/dev/null; }

# Ensure the helper pod exists AND is actually Running. A pod whose sleep has
# expired reports phase Succeeded, which still satisfies "kubectl get pod", so
# the phase must be checked explicitly or exec fails with "completed pod".
PHASE=$(kubectl get pod $BOX -n $NS -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
if [ "$PHASE" != "Running" ]; then
  [ -n "$PHASE" ] && kubectl delete pod $BOX -n $NS --ignore-not-found >/dev/null 2>&1
  kubectl run $BOX -n $NS --image=curlimages/curl:latest --restart=Never -- sleep 86400 >/dev/null
  kubectl wait --for=condition=Ready pod/$BOX -n $NS --timeout=180s >/dev/null
fi

# Hit a host through the ingress N times and tally which variant answered.
tally() {
  local host="$1" n="${2:-40}" extra="${3:-}"
  { for _ in $(seq 1 "$n"); do
      if [ -n "$extra" ]; then cingh "$host" /api/version "$extra"; else cing "$host" /api/version; fi
      echo
    done; } | grep -o '"variant":"[^"]*","version":"[^"]*"' \
            | sed 's/"variant":"//; s/","version":"/ v/; s/"$//' \
            | sort | uniq -c | sort -rn \
            | awk -v n="$n" '{printf "    %-20s %3d/%s  %5.1f%%\n", $2" "$3, $1, n, ($1/n)*100}'
}

# ===========================================================================
hdr "STRATEGY 1 of 5 - ROLLING UPDATE (zero downtime + rollback)"
sub "revision history"
kubectl rollout history deployment/aceest-rolling -n $NS 2>/dev/null | sed 's/^/    /'
sub "serving BEFORE"
echo "    $(cget http://aceest-rolling-svc/api/version)"
sub "rolling out v2.0.0  (maxUnavailable=0 so capacity never drops below 4)"
kubectl set image deployment/aceest-rolling aceest=2025tm93228/aceest-fitness:2.0.0 -n $NS >/dev/null
kubectl set env  deployment/aceest-rolling APP_VERSION=2.0.0 -n $NS >/dev/null
kubectl annotate deployment/aceest-rolling -n $NS \
  kubernetes.io/change-cause="Rolling update to v2.0.0" --overwrite >/dev/null
kubectl rollout status deployment/aceest-rolling -n $NS --timeout=240s 2>&1 | tail -1 | sed 's/^/    /'
sub "serving AFTER rollout"
echo "    $(cget http://aceest-rolling-svc/api/version)"
sub "ROLLBACK - kubectl rollout undo"
kubectl rollout undo deployment/aceest-rolling -n $NS >/dev/null 2>&1
kubectl rollout status deployment/aceest-rolling -n $NS --timeout=240s 2>&1 | tail -1 | sed 's/^/    /'
sub "serving AFTER rollback (reverted to last stable)"
echo "    $(cget http://aceest-rolling-svc/api/version)"

# ===========================================================================
hdr "STRATEGY 2 of 5 - BLUE-GREEN (atomic cutover + instant rollback)"
sub "live service, selector -> blue"
echo "    $(cget http://aceest-bluegreen-svc/api/version)"
sub "green preview, smoke tested privately before any cutover"
echo "    $(cget http://aceest-green-preview/api/version)"
sub "PROMOTE - patch the Service selector to green"
kubectl patch svc aceest-bluegreen-svc -n $NS \
  -p '{"spec":{"selector":{"app":"aceest-fitness","variant":"green"}}}' >/dev/null
sleep 3
echo "    $(cget http://aceest-bluegreen-svc/api/version)"
sub "ROLLBACK - patch the selector back to blue"
kubectl patch svc aceest-bluegreen-svc -n $NS \
  -p '{"spec":{"selector":{"app":"aceest-fitness","variant":"blue"}}}' >/dev/null
sleep 3
echo "    $(cget http://aceest-bluegreen-svc/api/version)"

# ===========================================================================
hdr "STRATEGY 3 of 5 - CANARY (weighted traffic split)"
kubectl annotate ingress aceest-canary-weighted -n $NS \
  nginx.ingress.kubernetes.io/canary-weight=20 --overwrite >/dev/null
sleep 3
sub "stable = 4 replicas v1.0.0   canary = 1 replica v2.0.0   weight = 20%"
echo "    stable svc: $(cget http://aceest-stable-svc/api/version)"
echo "    canary svc: $(cget http://aceest-canary-svc/api/version)"
sub "observed distribution through the ingress (40 requests)"
tally canary.aceest.local 40
sub "ROLLBACK - canary-weight set to 0"
kubectl annotate ingress aceest-canary-weighted -n $NS \
  nginx.ingress.kubernetes.io/canary-weight=0 --overwrite >/dev/null
sleep 3
tally canary.aceest.local 20

# ===========================================================================
hdr "STRATEGY 4 of 5 - A/B TESTING (deliberate header-based routing)"
sub "A = v1.0.0 control,  B = v2.0.0 experiment,  key = header X-Variant: B"
echo "    A svc: $(cget http://aceest-a-svc/api/version)"
echo "    B svc: $(cget http://aceest-b-svc/api/version)"
sub "WITHOUT the header (20 requests) - everyone stays on A"
tally ab.aceest.local 20
sub "WITH  X-Variant: B  (20 requests) - that cohort is routed to B"
tally ab.aceest.local 20 "X-Variant: B"

# ===========================================================================
hdr "STRATEGY 5 of 5 - SHADOW (traffic mirroring, responses discarded)"
sub "primary answers the user; shadow receives a copy it never replies with"
echo "    primary svc: $(cget http://aceest-primary-svc/api/version)"
echo "    shadow  svc: $(cget http://aceest-shadow-svc/api/version)"
sub "10 requests through the mirroring ingress - all answered by PRIMARY"
tally shadow.aceest.local 10
sub "shadow pod access log - the mirrored copies arriving"
kubectl logs -n $NS -l role=shadow --tail=6 2>/dev/null | sed 's/^/    /'

hdr "FINAL CLUSTER STATE"
kubectl get deploy -n $NS --no-headers | awk '{printf "    %-22s %s\n",$1,$2}'
