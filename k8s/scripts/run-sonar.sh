#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Run SonarQube analysis locally.
#   1. docker compose -f docker-compose.sonarqube.yml up -d
#   2. open http://localhost:9000, log in (admin/admin), create a user token
#   3. export SONAR_TOKEN=<token>  &&  ./k8s/scripts/run-sonar.sh
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${SONAR_TOKEN:?export SONAR_TOKEN=<your token> first}"
SONAR_HOST="${SONAR_HOST:-http://localhost:9000}"

# Produce the coverage report Sonar imports
. .venv/bin/activate 2>/dev/null || true
mkdir -p reports
pytest -q --cov=. --cov-report=xml:reports/coverage.xml --junitxml=reports/junit.xml

# Scanner runs in a container so nothing extra has to be installed locally
docker run --rm \
  -e SONAR_HOST_URL="${SONAR_HOST}" \
  -e SONAR_TOKEN="${SONAR_TOKEN}" \
  -v "$(pwd):/usr/src" \
  --network host \
  sonarsource/sonar-scanner-cli:latest

echo "Analysis submitted - open ${SONAR_HOST}/dashboard?id=aceest-fitness"
