# Pipeline Evidence

Visual proof that each stage of the ACEest Fitness & Gym DevOps pipeline was executed
successfully. Jenkins runs on a local lab VM and is not publicly reachable, so these
screenshots are the record of the BUILD stage completing without errors.

All images live in [`docs/screenshots/`](screenshots/); raw command output is in
[`docs/logs/`](logs/).

---

## A. Version Control (VCS Maturity)

| # | Screenshot | What it shows |
|---|---|---|
| 01 | `01-git-log-graph.png` | `git log --oneline --graph --all` — 9 commits across 3 merged branches |
| 02 | `02-github-repo-home.png` | Public repository landing page with the full file tree |
| 03 | `03-github-branches.png` | `feature/pytest-suite`, `infra/docker`, `infra/cicd` pushed to origin |

## B. Application Integrity

| # | Screenshot | What it shows |
|---|---|---|
| 04 | `04-flask-app-running.png` | Dashboard rendering at `http://localhost:5000` |
| 05 | `05-api-response.png` | Live JSON from `/api/bmi` and `/api/programs` |

## C. Testing Coverage

| # | Screenshot | What it shows |
|---|---|---|
| 06 | `06-pytest-pass.png` | Full suite green — 66 tests passed |
| 07 | `07-pytest-coverage.png` | Coverage report — 99% of statements |

## D. Docker Efficiency

| # | Screenshot | What it shows |
|---|---|---|
| 08 | `08-docker-build.png` | Multi-stage build completing |
| 09 | `09-docker-pytest-in-container.png` | Pytest executing **inside** the container |
| 10 | `10-docker-images-size.png` | `runtime` image smaller than `test` — dev deps excluded |
| 11 | `11-docker-container-running.png` | `docker ps` plus a successful `/health` response |

## E. GitHub Actions (CI)

| # | Screenshot | What it shows |
|---|---|---|
| 12 | `12-actions-workflow-list.png` | Workflow runs triggered automatically on push |
| 13 | `13-actions-jobs-green.png` | Both jobs green — `Build & Lint`, then Docker |
| 14 | `14-actions-container-test-step.png` | Expanded log of Pytest running in the container |

## F. Jenkins (BUILD Quality Gate)

| # | Screenshot | What it shows |
|---|---|---|
| 15 | `15-jenkins-job-config.png` | Pipeline-from-SCM configuration and Poll SCM trigger |
| 16 | `16-jenkins-build-stages-green.png` | All six stages green in the Stage View |
| 17 | `17-jenkins-console-output.png` | Console output ending in `Finished: SUCCESS` |
| 18 | `18-jenkins-test-results.png` | JUnit results published to the Jenkins UI |
| 19 | `19-jenkins-build-history.png` | Multiple builds — the pipeline is repeatable |
