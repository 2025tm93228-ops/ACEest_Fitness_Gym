# Pipeline Evidence

All 45 screenshots from the assignment session (13 October 2026, 18:08 – 19:39 IST) on the
Rocky Linux lab VM — Python 3.11, Docker, Jenkins 2.568.1. Files are in
[`screenshots/`](screenshots/), named chronologically by capture time.

Jenkins runs at `localhost:8080` on the lab VM and is not publicly reachable, so section **F**
is the record of the BUILD quality gate completing without errors.

---

## A. Version Control (VCS Maturity)

All four branches cloned and tracking `origin`:

![Branches](screenshots/06-6-38-59-pm.png)

`main` checked out, Flask server starting:

![On main](screenshots/11-6-58-10-pm.png)

Commit graph: [`logs/git-history.log`](logs/git-history.log) — 13 commits, three `--no-ff`
merges from `feature/pytest-suite`, `infra/docker` and `infra/cicd`.

---

## B. Application Integrity

Dashboard with live gym metrics:

![Dashboard](screenshots/12-6-58-30-pm.png)

All three training programmes with workout and nutrition plans:

![Programmes](screenshots/13-6-58-40-pm.png)

`POST /api/bmi` — 95 kg at 172 cm returns BMI 32.11, category *Obese*, recommends Fat Loss.
Devtools confirm **200 OK**:

![BMI API](screenshots/15-7-01-14-pm.png)

`POST /api/workouts` — validated, written to SQLite, returned with its new `id`.
Devtools confirm **201 CREATED**:

![Workout API](screenshots/16-7-02-55-pm.png)

---

## C. Testing Coverage

**66 tests passed**:

![Pytest](screenshots/09-6-51-51-pm.png)

Coverage **99%**, with `models.py` at 100%:

![Coverage](screenshots/10-6-52-33-pm.png)

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

![Docker build](screenshots/17-7-05-07-pm.png)

**Pytest executing inside the container** — the `docker run --rm aceest-fitness:test pytest -v`
command is visible, confirming the suite ran in the containerised environment, not on the host:

![Pytest in container](screenshots/19-7-06-44-pm.png)

The `runtime` image is **smaller than `test`** — the multi-stage build keeps pytest, pytest-cov
and flake8 out of production:

![Image sizes](screenshots/21-7-09-13-pm.png)

| Tag | Size | Contents |
|---|---|---|
| `aceest-fitness:test` | 137 MB | app + dev dependencies |
| `aceest-fitness:latest` | 131 MB | app only, non-root, gunicorn |

Container under gunicorn, Docker's own `HEALTHCHECK` reporting **healthy**:

![Docker ps](screenshots/23-7-10-39-pm.png)

`/health` responding from inside the container:

![Health endpoint](screenshots/24-7-11-17-pm.png)

---

## E. GitHub Actions (Continuous Integration)

Six workflow runs, all green, triggered automatically on push:

![Actions runs](screenshots/26-7-14-03-pm.png)

Both jobs passing in sequence — `Build & Lint` gates `Docker Image Assembly & Containerised Tests`:

![Actions jobs](screenshots/27-7-15-07-pm.png)

Docker build summary for both the `test` and `runtime` targets:

![Actions docker](screenshots/28-7-16-02-pm.png)

---

## F. Jenkins BUILD & Quality Gate

**Poll SCM** trigger (`H/5 * * * *`) — used instead of a webhook because GitHub cannot reach a
lab VM on a private network:

![Poll SCM](screenshots/34-7-30-19-pm.png)

**Pipeline script from SCM**, tracking `*/main`:

![Pipeline from SCM](screenshots/35-7-31-41-pm.png)

### Build #1 — all stages green

Checkout SCM → Checkout → Build Environment → Lint & Compile → Unit Tests (Quality Gate)
→ Docker Build → Container Smoke Test. Completed in 1 min 8 sec:

![Stages green](screenshots/40-7-34-56-pm.png)

Stage view including Post Actions:

![Post actions](screenshots/39-7-34-39-pm.png)

Console log — **66 passed**, with `junit.xml` and `coverage.xml` written to the workspace:

![Console](screenshots/41-7-35-38-pm.png)

### JUnit results published

Test Result Trend across builds #1 and #2, both 66 passing, no failures:

![Test trend](screenshots/43-7-37-34-pm.png)

### Build #2 — repeatable

Succeeded in 44 sec against revision `1b0aedb`, `Tests (no failures)`:

![Build 2](screenshots/45-7-39-09-pm.png)

Job dashboard — **Last Success #2, Last Failure: N/A**:

![Dashboard](screenshots/44-7-38-23-pm.png)

---

## Session timeline

The remaining screenshots cover setup and intermediate states:

| Time | Files | Phase |
|---|---|---|
| 18:08–18:10 | `01`–`03` | Repository creation; first push attempt (auth failure, resolved with a PAT) |
| 18:37–18:39 | `04`–`06` | Cloning; checking out all four branches |
| 18:50–18:52 | `07`–`10` | Python 3.11 virtualenv, dependencies, Pytest, coverage |
| 18:58–19:02 | `11`–`16` | Flask server, dashboard, programmes, BMI and workout APIs |
| 19:05–19:11 | `17`–`24` | Multi-stage Docker build, Pytest in container, image sizes, health |
| 19:13–19:16 | `25`–`28` | GitHub Actions runs and job detail |
| 19:23–19:31 | `29`–`36` | Jenkins startup, plugin install, job configuration |
| 19:32–19:39 | `37`–`45` | Jenkins builds #1 and #2 — stages, console, JUnit trend |

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
