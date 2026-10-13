#!/usr/bin/env bash
# Builds a meaningful, logically structured commit history for the assignment.
# Run ONCE inside the project folder, before adding the GitHub remote.
set -e

git init -b main
git add .gitignore README.md
git commit -m "chore: initialise repository with README and gitignore"

git add models.py
git commit -m "feat: add ACEest domain logic (programmes, BMI, adherence, validation)

Ported the training programme catalogue, nutrition plans and BMI logic from the
ACEest Tkinter prototypes into a Flask-free module so it can be unit-tested in isolation."

git add db.py
git commit -m "feat: add SQLite persistence layer bound to the Flask request lifecycle"

git add app.py templates static requirements.txt
git commit -m "feat: add Flask application with dashboard and JSON API

Implements the application factory, programme/BMI/adherence/workout endpoints,
a /health probe for CI and smoke tests, and HTML + JSON error handlers."

# --- feature branch: test suite ---
git checkout -b feature/pytest-suite
git add tests pytest.ini setup.cfg requirements-dev.txt
git commit -m "test: add Pytest suite covering domain logic and all routes

66 tests across models and routes, 99% statement coverage. Each test gets an
isolated temporary SQLite database so the suite is order-independent."
git checkout main
git merge --no-ff feature/pytest-suite -m "Merge branch 'feature/pytest-suite' into main"

# --- infra branch: docker ---
git checkout -b infra/docker
git add Dockerfile .dockerignore
git commit -m "build: containerise with a multi-stage Dockerfile

base -> test -> runtime so dev dependencies never ship to production.
Runs as the unprivileged aceest user under gunicorn with a HEALTHCHECK."
git checkout main
git merge --no-ff infra/docker -m "Merge branch 'infra/docker' into main"

# --- infra branch: ci/cd ---
git checkout -b infra/cicd
git add .github/workflows/main.yml
git commit -m "ci: add GitHub Actions pipeline for build, lint, Docker and tests

Triggered on every push and pull request. Lint/test job gates a second job that
builds the image and executes Pytest inside the container, then smoke-tests /health."
git add Jenkinsfile
git commit -m "ci: add declarative Jenkins pipeline for the BUILD quality gate

Rebuilds a clean virtualenv from scratch, publishes JUnit results for build-over-build
trends, and produces a build-numbered Docker image artefact."
git checkout main
git merge --no-ff infra/cicd -m "Merge branch 'infra/cicd' into main"

git add -A
git diff --cached --quiet || git commit -m "docs: expand README with setup, testing and pipeline documentation"

echo
echo "=== HISTORY ==="
git log --oneline --graph --all
