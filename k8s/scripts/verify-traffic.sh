#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Evidence generator. Hits an endpoint N times and tallies which version and
# variant answered. This is the proof that each traffic-splitting strategy is
# actually doing what it claims.
#
#   ./verify-traffic.sh http://127.0.0.1:PORT 50
#   ./verify-traffic.sh http://127.0.0.1:PORT 50 "X-Variant: B"
# ---------------------------------------------------------------------------
set -uo pipefail
URL="${1:?usage: $0 <url> [count] [extra-header]}"
N="${2:-50}"
HDR="${3:-}"

echo "Sampling $URL  ($N requests)${HDR:+  header: $HDR}"
echo "-------------------------------------------------------------"
for i in $(seq 1 "$N"); do
  if [ -n "$HDR" ]; then
    curl -s -H "$HDR" "$URL/api/version"
  else
    curl -s "$URL/api/version"
  fi
  echo
done | sed 's/.*"variant":"\([^"]*\)".*"version":"\([^"]*\)".*/\2 \1/;t;s/.*"version":"\([^"]*\)".*"variant":"\([^"]*\)".*/\1 \2/' \
     | sort | uniq -c | sort -rn \
     | awk -v n="$N" '{printf "  %-22s %4d requests  %5.1f%%\n", $2" / "$3, $1, ($1/n)*100}'
echo "-------------------------------------------------------------"
