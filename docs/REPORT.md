# ACEest Fitness & Gym — CI/CD Pipeline Implementation Report
**Introduction to DevOps (CSIZG514 / SEZG514) — Assignment 2**
**Name:** Namrata Rathore  **BITS ID:** 2025TM93228
**Repository:** https://github.com/2025tm93228-ops/ACEest_Fitness_Gym
**Docker Hub:** https://hub.docker.com/r/2025tm93228/aceest-fitness

---

## 1. CI/CD Architecture Overview

The pipeline takes a commit from a developer's machine to a running Kubernetes
workload without manual intervention, and refuses to publish anything that fails a
quality or test gate along the way.

```
Developer ──git push──► GitHub ──poll SCM (H/5 * * * *)──► Jenkins
                                                              │
   ┌──────────────────────────────────────────────────────────┘
   ▼
 1 Checkout        git clone + short SHA captured for image tagging
 2 Build Env       clean virtualenv from requirements-dev.txt
 3 Lint & Compile  compileall + flake8 (E9,F63,F7,F82 hard-fail)
 4 Unit Tests      pytest -> junit.xml + coverage.xml (69 tests)
 5 SonarQube       sonar-scanner uploads source + coverage
 6 Quality Gate    waitForQualityGate abortPipeline:true  ◄── blocks on failure
 7 Docker Build    multi-stage: test target + runtime target
 8 Container Test  pytest executed INSIDE the image
 9 Push            Docker Hub: :1.0.0, :<ver>-<build>-<sha>, :latest
10 Deploy          kubectl apply + set image, rollout status
11 Smoke Test      in-cluster curl of /health
   │
   └── post.failure ──► kubectl rollout undo  (automatic rollback)
```

**Design decisions worth noting.** The quality gate sits at step 6, *before* any image
is built or published, so a failing gate cannot produce an artefact that might later be
deployed by mistake. Tests run twice — once on the agent (step 4, fast feedback and
coverage for Sonar) and once inside the built image (step 8, proving the artefact itself
is sound rather than just the source tree). Images carry three tags: a semantic version,
an immutable `version-build-sha` tag for traceability back to a commit, and `latest` for
convenience.

**Application instrumentation.** `APP_VERSION`, `APP_VARIANT` and `POD_NAME` are injected
as environment variables and echoed by `/api/version`. This is what makes traffic
splitting externally observable: sampling the endpoint reveals which build and which
deployment track answered each request, which is the evidence base for Section 3.

---

## 2. Deployment Strategies Implemented

All five strategies were deployed to a Minikube cluster and verified by sampling
`/api/version` from a pod inside the cluster. Raw output:
[`docs/evidence-deployment-strategies.log`](evidence-deployment-strategies.log).

| # | Strategy | Mechanism | Rollback | Measured result |
|---|---|---|---|---|
| 1 | **Rolling Update** | `maxSurge:1, maxUnavailable:0` | `kubectl rollout undo` | v1.0.0 → v2.0.0 → v1.0.0, capacity never below 4 pods |
| 2 | **Blue-Green** | Service selector switch | re-patch selector | blue → green → blue, cutover atomic |
| 3 | **Canary** | nginx `canary-weight: 20` | weight → 0 | **32/40 stable (80.0%), 8/40 canary (20.0%)** |
| 4 | **A/B Testing** | nginx `canary-by-header: X-Variant` | delete experiment ingress | 20/20 on A without header, 20/20 on B with it |
| 5 | **Shadow** | nginx `mirror-target` | drop annotation | 10/10 answered by primary; shadow logs show mirrored copies |

**Why these are genuinely different.** Canary and A/B both split traffic but answer
different questions: canary splits *randomly by weight* to limit blast radius, whereas
A/B routes a *deliberate, identifiable cohort* by header so behaviour can be compared
reproducibly. Shadow is different again — the candidate receives real traffic but its
responses are discarded, so it carries zero user-facing risk, which neither canary nor
blue-green can claim. Blue-Green is the only one where rollback requires no pod
scheduling at all; the selector flip takes effect in milliseconds.

---

## 3. Challenges Faced and Mitigation Strategies

**Minikube refused to start (`K8S_INVALID_CERT_HOSTNAME`).** Cluster bootstrap failed
with `apiServer.certSANs: Invalid value: ""` — a known minikube defect (#9175) where a
stale profile leaves an empty certificate SAN. *Mitigation:* `minikube delete --all
--purge`, removal of `~/.minikube/machines` and `profiles`, and an explicit
`--apiserver-name=localhost` on restart. Documented in the README so the cluster can be
rebuilt reproducibly.

**Docker Desktop memory ceiling.** `--memory=4096` was rejected because Docker Desktop
had only 3918 MB allocated. *Mitigation:* profiled actual availability with
`docker info` and sized the cluster to 2 CPUs / 2800 MB, which runs all nine deployments
comfortably.

**Images not visible to the cluster.** This Minikube runs **containerd**, not Docker, so
`eval $(minikube docker-env)` — the usual advice — silently fails to make locally built
images available. *Mitigation:* build on the host daemon and transfer explicitly with
`minikube image load`, which is runtime-agnostic.

**NodePorts unreachable from the host.** With the Docker driver on macOS the node IP is
not routable from the host, so `curl $(minikube ip):30082` returned nothing.
*Mitigation:* all verification was moved into a `curlbox` pod running inside the
cluster. This removed the dependency on host networking entirely and, incidentally,
produces more representative evidence since it exercises real in-cluster service
discovery.

**`kubectl set image` did not change the reported version.** The first rolling-update
demonstration showed v1.0.0 before *and* after, because the version string is supplied
by an environment variable in the manifest, which `set image` does not touch — only the
pod hashes changed. *Mitigation:* the rollout now updates both (`set image` +
`set env`), making the version change visible in the evidence rather than merely implied.

**Port-forward instability during Blue-Green cutover.** Patching the Service selector
invalidates existing port-forward tunnels, which produced empty responses mid-demo.
*Mitigation:* the in-cluster `curlbox` approach again, which follows the selector change
without reconnection.

---

## 4. Key Automation Outcomes

- **Zero-touch path from commit to cluster.** Jenkins polls every five minutes; a push
  triggers lint, 69 unit tests, Sonar analysis, quality gate, image build, containerised
  re-test, registry push, deployment and smoke test with no human step.
- **Quality enforced, not merely reported.** `abortPipeline: true` means a failed Sonar
  gate stops the build before an image exists, rather than producing a dashboard nobody
  reads.
- **Artefacts traceable to commits.** Every image carries a `version-build-sha` tag, so
  any running pod can be traced to the exact commit that produced it.
- **Rollback is automated and strategy-specific.** `post { failure { ... } }` issues a
  `rollout undo` automatically, and each strategy has a scripted, tested rollback path
  (`k8s/scripts/rollback.sh`).
- **Measured, not assumed.** The traffic splits above are observed percentages from 40-
  and 20-request samples, not configuration values quoted back. The canary landed on
  exactly the configured 80/20.

### Honest limitations

The cluster is Minikube on a laptop, so the endpoints are **not publicly reachable** —
the submitted URLs are in-cluster service names and NodePort addresses reachable via
`minikube service` or `kubectl port-forward`. A genuinely public endpoint would require
a managed cluster (GKE/EKS/AKS); the manifests are portable and would apply unchanged,
but the hosting cost was out of scope. The shadow implementation uses the NGINX ingress
`mirror-target` annotation rather than a service mesh; Istio would give finer control
(percentage mirroring, response comparison) at a substantially higher operational cost
for this scale.
