# Pipeline Evidence

All 45 screenshots from the assignment session (13 October 2026, 18:08 – 19:39 IST) on the
Rocky Linux lab VM — Python 3.11, Docker, Jenkins 2.568.1. Files are in
[`screenshots/`](screenshots/), numbered in capture order and named by content.

Jenkins runs at `localhost:8080` on the lab VM and is not publicly reachable, so section **F**
is the record of the BUILD quality gate completing without errors.

---

## A. Version Control (VCS Maturity)

| | |
|---|---|
| [`01`](screenshots/01-github-repo-created-empty.png) | Public repository created |
| [`02`](screenshots/02-clone-and-first-commit-attempt.png) | Clone and initial commit attempt |
| [`03`](screenshots/03-push-fails-password-auth-rejected.png) | Push rejected — GitHub no longer accepts password auth; resolved with a Personal Access Token |
| [`04`](screenshots/04-checkout-feature-pytest-suite-branch.png) · [`05`](screenshots/05-checkout-infra-cicd-branch.png) | Feature and infrastructure branches checked out |

All four branches tracking `origin`:

![Branches](screenshots/06-all-four-branches-tracking-origin.png)

Commit graph: [`logs/git-history.log`](logs/git-history.log) — 13 commits, three `--no-ff`
merges from `feature/pytest-suite`, `infra/docker` and `infra/cicd`.

---

## B. Application Integrity

Environment prepared with Python 3.11 ([`07`](screenshots/07-python311-virtualenv-created.png),
[`08`](screenshots/08-install-dependencies-flask-pytest.png)), then `main` checked out and the
server started:

![Server start](screenshots/11-on-main-flask-server-start.png)

Dashboard with live gym metrics:

![Dashboard](screenshots/12-flask-dashboard-gym-metrics.png)

All three training programmes ([`13`](screenshots/13-flask-training-programmes.png)) and the
input forms ([`14`](screenshots/14-flask-bmi-and-workout-forms.png)).

`POST /api/bmi` — 95 kg at 172 cm returns BMI 32.11, category *Obese*, recommends Fat Loss.
Devtools confirm **200 OK**:

![BMI API](screenshots/15-api-bmi-200-ok-devtools.png)

`POST /api/workouts` — validated, written to SQLite, returned with its new `id`.
Devtools confirm **201 CREATED**:

![Workout API](screenshots/16-api-workout-201-created-devtools.png)

Flask access log confirming the same requests server-side:

![Access log](screenshots/18-flask-access-log-api-requests.png)

---

## C. Testing Coverage

**66 tests passed**:

![Pytest](screenshots/09-pytest-66-tests-passed.png)

Coverage **99%**, with `models.py` at 100%:

![Coverage](screenshots/10-pytest-coverage-99-percent.png)

| Module | Statements | Coverage |
|---|---|---|
| `models.py` | 61 | 100% |
| `app.py` | 85 | 99% |
| `db.py` | 22 | 95% |
| **Total** | **355** | **99%** |

Raw output: [`logs/pytest.log`](logs/pytest.log) · [`logs/pytest-coverage.log`](logs/pytest-coverage.log)

---

## D. Docker Efficiency

Multi-stage build of the `test` target:

![Docker build](screenshots/17-docker-build-test-image.png)

**Pytest executing inside the container** — the `docker run --rm aceest-fitness:test pytest -v`
command is visible, confirming the suite ran in the containerised environment, not on the host:

![Pytest in container](screenshots/19-pytest-running-inside-container.png)

Runtime image built ([`20`](screenshots/20-docker-build-runtime-image.png)). The `runtime` image
is **smaller than `test`** — the multi-stage build keeps pytest, pytest-cov and flake8 out of
production:

![Image sizes](screenshots/21-docker-images-test-vs-runtime-size.png)

| Tag | Size | Contents |
|---|---|---|
| `aceest-fitness:test` | 137 MB | app + dev dependencies |
| `aceest-fitness:latest` | 131 MB | app only, non-root, gunicorn |

Container started detached ([`22`](screenshots/22-docker-run-detached-container.png)) and
reporting Docker's own `HEALTHCHECK` as **healthy**:

![Docker ps](screenshots/23-docker-ps-container-healthy.png)

`/health` responding from inside the container:

![Health endpoint](screenshots/24-docker-health-endpoint-response.png)

---

## E. GitHub Actions (Continuous Integration)

Six workflow runs, all green, triggered automatically on push
([`25`](screenshots/25-actions-all-workflows.png)):

![Actions runs](screenshots/26-actions-six-runs-all-green.png)

Both jobs passing in sequence — `Build & Lint` gates `Docker Image Assembly & Containerised Tests`:

![Actions jobs](screenshots/27-actions-both-jobs-green.png)

Docker build summary for both the `test` and `runtime` targets:

![Actions docker](screenshots/28-actions-docker-build-summary.png)

---

## F. Jenkins BUILD & Quality Gate

Required plugins installed — Git ([`29`](screenshots/29-jenkins-git-plugin-installed.png)) and
JUnit ([`30`](screenshots/30-jenkins-junit-plugin-installed.png)) — then Jenkins restarted
([`31`](screenshots/31-jenkins-restarting-after-plugins.png)).

Pipeline job created ([`32`](screenshots/32-jenkins-new-pipeline-item.png),
[`33`](screenshots/33-jenkins-job-general-config.png)).

**Poll SCM** trigger (`H/5 * * * *`) — used instead of a webhook because GitHub cannot reach a
lab VM on a private network:

![Poll SCM](screenshots/34-jenkins-poll-scm-trigger.png)

**Pipeline script from SCM**, pointed at this repository and tracking
`*/main` ([`35`](screenshots/35-jenkins-branch-specifier-main.png)):

![Pipeline from SCM](screenshots/36-jenkins-pipeline-script-from-scm.png)

### Build #1 — all stages green

Job created with no builds yet ([`37`](screenshots/37-jenkins-job-created-no-builds.png)), then
the first build runs ([`38`](screenshots/38-jenkins-build1-in-progress.png),
[`39`](screenshots/39-jenkins-build1-stages-with-post-actions.png)).

Checkout SCM → Checkout → Build Environment → Lint & Compile → Unit Tests (Quality Gate)
→ Docker Build → Container Smoke Test. Completed in 1 min 8 sec:

![Stages green](screenshots/40-jenkins-build1-all-stages-green.png)

Console log — **66 passed**, with `junit.xml` and `coverage.xml` written to the workspace:

![Console](screenshots/41-jenkins-console-66-tests-passed.png)

### JUnit results published

Test Result Trend after build #1 ([`42`](screenshots/42-jenkins-test-trend-after-build1.png)),
then across builds #1 and #2 — both 66 passing, no failures:

![Test trend](screenshots/43-jenkins-test-trend-build1-and-build2.png)

### Build #2 — repeatable

Job dashboard showing **Last Success #2, Last Failure: N/A**:

![Dashboard](screenshots/44-jenkins-dashboard-last-success.png)

Build #2 succeeded in 44 sec against revision `1b0aedb`, `Tests (no failures)`:

![Build 2](screenshots/45-jenkins-build2-success-44sec.png)

---

## Summary

| Evaluation criterion | Evidence |
|---|---|
| Application Integrity | §B — dashboard, `200 OK` on BMI, `201 CREATED` on workout write |
| VCS Maturity | §A — 13 commits, 4 branches, 3 `--no-ff` merges |
| Testing Coverage | §C — 66 tests, 99% statement coverage |
| Docker Efficiency | §D — multi-stage, non-root, runtime smaller than test image |
| Pipeline Reliability (GitHub Actions) | §E — 6 green runs triggered on push |
| Pipeline Reliability (Jenkins) | §F — builds #1 and #2 green across all 7 stages, zero failures |
