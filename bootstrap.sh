#!/usr/bin/env bash
# ACEest Fitness & Gym - VM bootstrap for the DevOps assignment.
# Idempotent: safe to re-run. Run individual stages if one fails.
#
#   ./bootstrap.sh all        # everything that needs no secrets
#   ./bootstrap.sh deps       # apt packages + docker
#   ./bootstrap.sh git        # build the commit history
#   ./bootstrap.sh test       # venv + pytest
#   ./bootstrap.sh docker     # build images, run tests in container, smoke test
#   ./bootstrap.sh jenkins    # install Jenkins, print admin password
#   ./bootstrap.sh push       # push to GitHub via gh CLI (interactive login)
#   ./bootstrap.sh verify     # re-check everything and print a submission checklist

set -euo pipefail
cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"
STAGE="${1:-all}"

say()  { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  [OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m  [!!]\033[0m %s\n' "$*"; }

need_sudo() {
  if ! sudo -n true 2>/dev/null; then
    say "sudo password needed once (for apt / docker / jenkins)"
    sudo -v
  fi
}

# ---------------------------------------------------------------- deps
stage_deps() {
  say "STAGE 1/6  System dependencies"
  need_sudo
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -qq
  sudo apt-get install -y -qq python3-venv python3-pip git curl wget unzip ca-certificates
  ok "python3 $(python3 --version 2>&1 | awk '{print $2}'), git $(git --version | awk '{print $3}')"

  if ! command -v docker >/dev/null 2>&1; then
    sudo apt-get install -y -qq docker.io
  fi
  sudo systemctl enable --now docker 2>/dev/null || true

  if ! docker info >/dev/null 2>&1; then
    sudo usermod -aG docker "$USER"
    warn "Added $USER to the docker group."
    warn "Docker needs a NEW shell: run 'newgrp docker' (or log out/in), then re-run:"
    warn "    ./bootstrap.sh docker"
  else
    ok "docker $(docker --version | awk '{print $3}' | tr -d ,) usable without sudo"
  fi
}

# ---------------------------------------------------------------- git
stage_git() {
  say "STAGE 2/6  Git commit history"
  if [ -d .git ]; then
    ok "git repo already exists ($(git rev-list --count HEAD 2>/dev/null || echo 0) commits) - skipping"
    return 0
  fi
  if ! git config --global user.email >/dev/null 2>&1; then
    warn "Set your identity first, then re-run './bootstrap.sh git':"
    warn '    git config --global user.name  "Your Name"'
    warn '    git config --global user.email "you@example.com"'
    return 1
  fi
  ./setup_git_history.sh
  ok "$(git rev-list --count HEAD) commits on $(git branch --show-current)"
}

# ---------------------------------------------------------------- test
stage_test() {
  say "STAGE 3/6  Virtualenv + Pytest"
  [ -d .venv ] || python3 -m venv .venv
  # shellcheck disable=SC1091
  source .venv/bin/activate
  pip install -q --upgrade pip
  pip install -q -r requirements-dev.txt
  ok "dependencies installed"

  python -m compileall -q app.py db.py models.py tests
  ok "all sources compile"

  flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
  ok "no critical lint errors"

  pytest -v --cov=. --cov-report=term-missing
  ok "test suite passed  <-- SCREENSHOT THIS"
}

# ---------------------------------------------------------------- docker
stage_docker() {
  say "STAGE 4/6  Docker build + containerised tests"
  if ! docker info >/dev/null 2>&1; then
    warn "Cannot talk to the Docker daemon. Run 'newgrp docker' then retry."
    return 1
  fi

  docker build --target test -t aceest-fitness:test .
  ok "test image built"

  docker run --rm aceest-fitness:test pytest -v
  ok "Pytest passed INSIDE the container  <-- SCREENSHOT THIS"

  docker build --target runtime -t aceest-fitness:latest .
  ok "runtime image built"

  docker rm -f aceest >/dev/null 2>&1 || true
  docker run -d --name aceest -p 5000:5000 aceest-fitness:latest >/dev/null

  for i in $(seq 1 20); do
    if curl -fsS http://localhost:5000/health >/dev/null 2>&1; then break; fi
    printf '  waiting for container... (%s)\r' "$i"; sleep 1
  done

  echo
  if curl -fsS http://localhost:5000/health | grep -q healthy; then
    curl -s http://localhost:5000/health; echo
    curl -s http://localhost:5000/api/programs | head -c 120; echo '...'
    ok "container serving on http://localhost:5000  <-- OPEN IN BROWSER + SCREENSHOT"
  else
    warn "Health check failed. Logs:"; docker logs aceest
    return 1
  fi

  say "Image sizes (runtime should be smaller than test)"
  docker images aceest-fitness
  warn "Container left running on port 5000. Stop it with: docker rm -f aceest"
}

# ---------------------------------------------------------------- jenkins
stage_jenkins() {
  say "STAGE 5/6  Jenkins"
  need_sudo
  export DEBIAN_FRONTEND=noninteractive

  if ! command -v java >/dev/null 2>&1; then
    sudo apt-get install -y -qq fontconfig openjdk-17-jre
  fi
  ok "java $(java -version 2>&1 | head -1 | grep -o '"[^"]*"' | tr -d '"')"

  if ! command -v jenkins >/dev/null 2>&1 && [ ! -d /var/lib/jenkins ]; then
    sudo wget -q -O /usr/share/keyrings/jenkins-keyring.asc \
      https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
      | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq jenkins
  fi

  # Jenkins must be able to run docker for the Docker Build stage
  sudo usermod -aG docker jenkins 2>/dev/null || true
  sudo systemctl enable --now jenkins
  sleep 5
  sudo systemctl restart jenkins
  ok "jenkins service: $(systemctl is-active jenkins)"

  for i in $(seq 1 45); do
    if curl -fsS -o /dev/null http://localhost:8080/login 2>/dev/null; then break; fi
    printf '  waiting for Jenkins to come up... (%s)\r' "$i"; sleep 2
  done
  echo

  cat <<'BANNER'

  ------------------------------------------------------------------
  JENKINS IS UP - these final steps must be done in the browser
  (you need the screenshots from the UI for submission anyway)
  ------------------------------------------------------------------
  1. Open  http://localhost:8080
  2. Paste the admin password printed below
  3. Choose "Install suggested plugins"  (~5 min; includes Git,
     Pipeline and JUnit - all three are required)
  4. Create your admin user
  5. New Item -> name: ACEest-Fitness-Build -> type: Pipeline -> OK
       Build Triggers : [x] Poll SCM      Schedule: H/5 * * * *
       Pipeline       : Pipeline script from SCM
       SCM            : Git
       Repository URL : https://github.com/YOUR_USERNAME/ACEest_Fitness_Gym.git
       Branch         : */main
       Script Path    : Jenkinsfile
  6. Save -> Build Now -> screenshot all 6 green stages
  ------------------------------------------------------------------

BANNER

  echo "  Initial admin password:"
  sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null \
    || warn "already past setup - use the admin account you created"
  echo
}

# ---------------------------------------------------------------- push
stage_push() {
  say "STAGE 6/6  Push to GitHub"
  [ -d .git ] || { warn "No git repo yet. Run './bootstrap.sh git' first."; return 1; }

  if ! command -v gh >/dev/null 2>&1; then
    say "Installing the GitHub CLI (handles auth without copy-pasting tokens)"
    need_sudo
    export DEBIAN_FRONTEND=noninteractive
    if sudo apt-get install -y -qq gh 2>/dev/null; then
      ok "gh installed from apt"
    else
      sudo mkdir -p -m 755 /etc/apt/keyrings
      wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      sudo apt-get update -qq && sudo apt-get install -y -qq gh
    fi
  fi

  if ! gh auth status >/dev/null 2>&1; then
    warn "Logging in to GitHub. Choose: GitHub.com -> HTTPS -> Yes (git credentials)"
    warn "            -> Login with a web browser, then enter the one-time code."
    gh auth login
  fi
  ok "authenticated as $(gh api user -q .login)"

  if gh repo view ACEest_Fitness_Gym >/dev/null 2>&1; then
    ok "repo already exists"
    git remote get-url origin >/dev/null 2>&1 || \
      git remote add origin "https://github.com/$(gh api user -q .login)/ACEest_Fitness_Gym.git"
    git push -u origin main
  else
    gh repo create ACEest_Fitness_Gym --public --source=. --remote=origin --push
  fi

  git push origin feature/pytest-suite infra/docker infra/cicd 2>/dev/null || true

  local url="https://github.com/$(gh api user -q .login)/ACEest_Fitness_Gym"
  ok "pushed -> $url"
  echo "  Actions: $url/actions   <-- SCREENSHOT both jobs green"
}

# ---------------------------------------------------------------- verify
stage_verify() {
  say "Submission checklist"
  local pass=0 fail=0
  chk() { if eval "$2" >/dev/null 2>&1; then ok "$1"; pass=$((pass+1)); else warn "$1"; fail=$((fail+1)); fi; }

  chk "Flask app, models, db present"   "test -f app.py -a -f models.py -a -f db.py"
  chk "Pytest suite present"            "test -d tests -a -f tests/conftest.py"
  chk "Dockerfile present"              "test -f Dockerfile"
  chk "GitHub Actions workflow present" "test -f .github/workflows/main.yml"
  chk "Jenkinsfile present"             "test -f Jenkinsfile"
  chk "README present"                  "test -f README.md"
  chk "Git history (>=8 commits)"        "test \$(git rev-list --count HEAD 2>/dev/null || echo 0) -ge 8"
  chk "Feature/infra branches exist"    "git branch | grep -q feature/pytest-suite"
  chk "GitHub remote configured"        "git remote get-url origin"
  chk "Docker usable"                   "docker info"
  chk "Runtime image built"             "docker image inspect aceest-fitness:latest"
  chk "Jenkins responding on :8080"     "curl -fsS -o /dev/null http://localhost:8080/login"

  printf '\n  %s passed, %s outstanding\n\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] && ok "All green. Confirm the repo is PUBLIC, then submit the URL."
}

case "$STAGE" in
  deps)    stage_deps ;;
  git)     stage_git ;;
  test)    stage_test ;;
  docker)  stage_docker ;;
  jenkins) stage_jenkins ;;
  push)    stage_push ;;
  verify)  stage_verify ;;
  all)
    stage_deps
    stage_git   || warn "git stage incomplete - see above"
    stage_test
    stage_docker || warn "docker stage incomplete - see above"
    say "Next: ./bootstrap.sh push      (GitHub, interactive login)"
    say "Then: ./bootstrap.sh jenkins   (~10 min)"
    say "Last: ./bootstrap.sh verify"
    ;;
  *) warn "Unknown stage '$STAGE'. Use: all|deps|git|test|docker|jenkins|push|verify"; exit 1 ;;
esac
