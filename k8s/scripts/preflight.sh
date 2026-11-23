#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Run this FIRST on any new machine (e.g. the Prayogshala VM) to find out
# whether it can host this assignment, before spending time on setup.
#
#   ./k8s/scripts/preflight.sh
# ---------------------------------------------------------------------------
ok()   { printf '  \033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn() { printf '  \033[1;33m[WARN]\033[0m %s\n' "$*"; }
bad()  { printf '  \033[1;31m[FAIL]\033[0m %s\n' "$*"; }
hdr()  { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

VERDICT_FULL=1; VERDICT_LITE=1

hdr "Operating system"
if [ -r /etc/os-release ]; then . /etc/os-release; ok "$PRETTY_NAME"; else ok "$(uname -srm)"; fi

hdr "CPU"
CPUS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 0)
if   [ "$CPUS" -ge 4 ]; then ok "$CPUS cores"
elif [ "$CPUS" -ge 2 ]; then warn "$CPUS cores - enough for lite mode only"; VERDICT_FULL=0
else bad "$CPUS cores - minikube needs at least 2"; VERDICT_FULL=0; VERDICT_LITE=0; fi

hdr "Memory"
if [ -r /proc/meminfo ]; then
  TOTAL_MB=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 ))
  FREE_MB=$((  $(awk '/MemAvailable/{print $2}' /proc/meminfo) / 1024 ))
else
  TOTAL_MB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1048576 )); FREE_MB=$TOTAL_MB
fi
echo "    total: ${TOTAL_MB} MB   available: ${FREE_MB} MB"
if   [ "$FREE_MB" -ge 4000 ]; then ok "enough for the FULL 20-pod deployment"
elif [ "$FREE_MB" -ge 2600 ]; then warn "tight - use LITE mode (11 pods)"; VERDICT_FULL=0
else bad "under 2600 MB available - minikube will not start reliably"; VERDICT_FULL=0; VERDICT_LITE=0; fi

hdr "Disk"
# df -k is POSIX and works on both GNU/Linux and BSD/macOS; -BG is GNU-only.
AVAIL_GB=$(df -k / 2>/dev/null | awk 'NR==2{printf "%d", $4/1048576}')
AVAIL_GB=${AVAIL_GB:-0}
if [ "${AVAIL_GB:-0}" -ge 15 ]; then ok "${AVAIL_GB} GB free on /"
elif [ "${AVAIL_GB:-0}" -ge 8 ]; then warn "${AVAIL_GB} GB free - minikube image is ~470 MB plus layers"
else bad "${AVAIL_GB} GB free - likely insufficient"; VERDICT_FULL=0; VERDICT_LITE=0; fi

hdr "Required tooling"
for t in docker kubectl minikube git python3; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t  $($t --version 2>/dev/null | head -1 | cut -c1-50)"
  else
    case "$t" in
      minikube) warn "$t missing - install: curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install minikube-linux-amd64 /usr/local/bin/minikube" ;;
      kubectl)  warn "$t missing - install: curl -LO https://dl.k8s.io/release/\$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && sudo install kubectl /usr/local/bin/" ;;
      docker)   bad  "$t missing - install: sudo dnf install -y docker-ce  (or podman)"; VERDICT_FULL=0; VERDICT_LITE=0 ;;
      *)        bad  "$t missing"; ;;
    esac
  fi
done

hdr "Docker daemon"
if docker info >/dev/null 2>&1; then ok "reachable without sudo"
elif sudo -n docker info >/dev/null 2>&1; then warn "needs sudo - run: sudo usermod -aG docker \$USER && newgrp docker"
else bad "not running - run: sudo systemctl enable --now docker"; VERDICT_FULL=0; VERDICT_LITE=0; fi

hdr "Network (image pulls)"
for host in registry-1.docker.io github.com; do
  if curl -sI --max-time 8 "https://$host" >/dev/null 2>&1; then ok "$host reachable"
  else bad "$host unreachable - images cannot be pulled"; VERDICT_FULL=0; VERDICT_LITE=0; fi
done

hdr "Ports already in use"
for p in 8080 9000; do
  if (command -v ss >/dev/null && ss -ltn 2>/dev/null | grep -q ":$p ") || \
     (command -v lsof >/dev/null && lsof -nP -iTCP:$p -sTCP:LISTEN >/dev/null 2>&1); then
    ok "port $p in use (Jenkins/SonarQube probably already running - good)"
  else
    warn "port $p free (Jenkins on 8080 / SonarQube on 9000 not yet started)"
  fi
done

hdr "VERDICT"
if   [ "$VERDICT_FULL" -eq 1 ]; then
  printf '  \033[1;32mFULL deployment viable.\033[0m  ./k8s/scripts/deploy.sh all\n'
elif [ "$VERDICT_LITE" -eq 1 ]; then
  printf '  \033[1;33mLITE mode only.\033[0m  Run: ./k8s/scripts/deploy.sh all && ./k8s/scripts/lite-mode.sh\n'
  printf '  This reduces 20 pods to 11. All five strategies still work - the canary\n'
  printf '  split is driven by the ingress weight annotation, not the replica ratio.\n'
else
  printf '  \033[1;31mThis machine cannot host the cluster.\033[0m\n'
  printf '  Options: (a) run the Kubernetes part on your Mac and Jenkins on the VM,\n'
  printf '           (b) request a larger VM, (c) use a free-tier managed cluster.\n'
fi
echo
