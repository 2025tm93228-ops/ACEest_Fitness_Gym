# Application Version Lineage

This folder holds the **original Tkinter desktop prototypes** supplied with the
assignment, preserved unmodified for traceability.

| File | Notes |
|---|---|
| `Aceestver-1.0.py` | Baseline: programme catalogue + workout/diet charts |
| `Aceestver-1.1.py`, `Aceestver1.1.2.py` | UI iterations |
| `Aceestver2.0.1.py`, `Aceestver-2.1.2.py`, `Aceestver-2.2.1.py` | Client profiles, metrics |
| `Aceestver-2.2.4.py`, `Aceestver-3.0.1.py` | SQLite persistence, charts, PDF reports |
| `Aceestver-3.1.2.py`, `Aceestver-3.2.4.py` | Role-based login, membership billing |

## How these relate to the deployed application

These prototypes are **Tkinter desktop applications** — they open a GUI window and
cannot be containerised or served over HTTP. For Assignment 1 the domain logic was
therefore ported into a stateless Flask web service, which is what the CI/CD pipeline
builds, tests and deploys:

| Prototype concept | Where it lives now |
|---|---|
| Programme catalogue, workout and diet charts | `models.py` → `PROGRAMS`, `list_programs()` |
| BMI / client metrics | `models.py` → `calculate_bmi()`, `bmi_category()` |
| Workout logging | `models.py` → `validate_workout()`, `db.py` |
| Adherence tracking | `models.py` → `adherence_score()` |
| Gym capacity metrics | `models.py` → `GYM_METRICS` |

## Deployed versions

The versions actually built, pushed and deployed by the pipeline are tagged in Git
and published to Docker Hub:

| Git tag | Docker image | Deployment role |
|---|---|---|
| `v1.0.0` | `2025tm93228/aceest-fitness:1.0.0` | blue / stable / variant A / primary |
| `v2.0.0` | `2025tm93228/aceest-fitness:2.0.0` | green / canary / variant B / shadow |
