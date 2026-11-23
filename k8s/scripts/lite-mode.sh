#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Halve the cluster footprint for resource-constrained machines: 20 pods -> 11.
#
# All five strategies remain fully demonstrable. In particular the canary
# 80/20 split is enforced by the NGINX ingress canary-weight annotation, NOT by
# the replica ratio, so reducing the stable track from 4 replicas to 2 does not
# change the measured distribution.
# ---------------------------------------------------------------------------
set -euo pipefail
NS=aceest
echo "Scaling down for lite mode..."
kubectl scale deployment aceest-rolling    --replicas=2 -n $NS
kubectl scale deployment aceest-blue       --replicas=1 -n $NS
kubectl scale deployment aceest-green      --replicas=1 -n $NS
kubectl scale deployment aceest-stable     --replicas=2 -n $NS
kubectl scale deployment aceest-canary     --replicas=1 -n $NS
kubectl scale deployment aceest-variant-a  --replicas=1 -n $NS
kubectl scale deployment aceest-variant-b  --replicas=1 -n $NS
kubectl scale deployment aceest-primary    --replicas=1 -n $NS
kubectl scale deployment aceest-shadow     --replicas=1 -n $NS
echo
kubectl get deploy -n $NS --no-headers | awk '{s+=substr($2,3)} {printf "  %-22s %s\n",$1,$2} END {print "  total pods: " s}'
