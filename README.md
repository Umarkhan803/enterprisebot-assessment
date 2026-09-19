# Enterprise Bot — DevOps Take-Home Assignment

This repository contains my submission for the Enterprise Bot DevOps / Platform Engineer take-home assignment.

## Repository Structure

```text
.
├── setup.sh
├── README.md
├── ANSWERS.md
├── service/
├── chart/
└── lab/
    ├── scenario.sh
    ├── cluster-state/
    ├── broken-chart/
    ├── FINDINGS.md
    └── part4-session.log
```

## Prerequisites

The assignment is designed to run locally.

Required tools:

- Docker
- kind
- kubectl
- Helm

The setup uses a kind cluster named `demo`.

---

# Part 1 — Containerized Service

The application is implemented in Node.js using Express.

The service exposes:

```text
GET /
GET /health
GET /healthz
```

`GET /` returns:

```json
{
  "app": "<APP_NAME>",
  "version": "<VERSION>",
  "pod": "<hostname>"
}
```

`APP_NAME` and `VERSION` are read from environment variables.

The application listens on port `3000`.

The Dockerfile uses a multi-stage build, a pinned Node.js base image, and runs the application as a non-root user.

## Build locally

From the repository root:

```bash
docker build -t server:1.0 ./service
```

## Test locally

```bash
docker run --rm   -p 3000:3000   -e APP_NAME=enterprisebot-demo   -e VERSION=1.0.0   server:1.0
```

Then:

```bash
curl http://localhost:3000/
curl http://localhost:3000/health
```

---

# Part 2 — Helm Chart

The Helm chart is located in:

```text
chart/
```

The default configuration uses:

```yaml
replicaCount: 2
```

The application configuration is supplied through a ConfigMap.

The chart also includes:

- Deployment
- Service
- Ingress
- liveness probe
- readiness probe
- CPU requests and limits
- memory requests and limits
- configurable image repository/tag
- configurable APP_NAME/VERSION

The probes use:

```text
/healthz
```

The Ingress host is:

```text
demo.local
```

## Resource choices

The default application resources are:

```yaml
requests:
  cpu: 100m
  memory: 64Mi

limits:
  cpu: 250m
  memory: 128Mi
```

I chose a small CPU request because this is a lightweight HTTP service and does not need a large guaranteed CPU allocation. `100m` provides a predictable baseline while allowing Kubernetes to schedule multiple replicas efficiently.

The `250m` CPU limit provides headroom for short bursts without allowing one application container to consume excessive CPU.

The memory request of `64Mi` is intended to provide a small guaranteed baseline for the Node.js process. The `128Mi` limit provides additional room for runtime overhead while keeping the container bounded.

These values are starting points rather than production capacity measurements. In production I would validate them against real CPU/memory utilization and tune them using workload metrics.

---

# Part 3 — One-Command Setup

The root-level:

```text
setup.sh
```

creates or reuses the kind cluster:

```text
demo
```

It then:

1. Installs ingress-nginx if required.
2. Builds the application image.
3. Loads the image into kind.
4. Creates the `demo` namespace.
5. Installs/upgrades the Helm release named `demo`.
6. Waits for the deployment to become ready.

The script is designed to be idempotent so it can be run more than once.

## Run setup

From the repository root:

```bash
chmod +x setup.sh
./setup.sh
```

Run it again to verify idempotency:

```bash
./setup.sh
```

## Verify the deployment

```bash
kubectl get pods -n demo
kubectl get svc -n demo
kubectl get ingress -n demo
```

The expected application replicas are:

```text
2
```

## Test through the Ingress

Add the local hostname if required:

```bash
echo "127.0.0.1 demo.local" | sudo tee -a /etc/hosts
```

Then:

```bash
curl -H "Host: demo.local" http://127.0.0.1/
```

Health check:

```bash
curl -H "Host: demo.local" http://127.0.0.1/health
```

The response from `/` should contain the configured application name,
version, and the hostname of the serving Pod.

---

# Part 4 — Debug Lab

The supplied debugging lab is located under:

```text
lab/
```

I kept:

```text
lab/scenario.sh
lab/cluster-state/
```

unchanged and made the debugging changes under:

```text
lab/broken-chart/
```

The debugging session was recorded in:

```text
lab/part4-session.log
```

## Run the lab

```bash
cd lab
./scenario.sh up
```

Verify:

```bash
./scenario.sh verify
```

Reset when necessary:

```bash
./scenario.sh reset
```

## Findings

The six configuration defects investigated in the lab were:

1. Reporter RBAC RoleBinding
2. Migration Job restart policy
3. Reporter/container non-root security configuration
4. Metrics CPU resource limit
5. Worker writable cache with read-only root filesystem
6. Gateway backend namespace/Service URL

The detailed diagnostic path, commands, observations, causes, and fixes are documented in:

```text
lab/FINDINGS.md
```

## Reporter investigation

During the investigation, the reporter continued to report:

```text
pod list failed: parse pod list: unexpected end of JSON input
```

I verified that:

- the reporter ServiceAccount was being used;
- the RoleBinding was correctly bound to the reporter ServiceAccount after the RBAC fix;
- the ServiceAccount could list Pods;
- the Kubernetes API returned HTTP 200 when queried with the same ServiceAccount;
- the returned PodList was complete JSON;
- the reporter container remained running;
- testing without the restrictive filesystem/security configuration did not remove the parsing error.

I therefore did not introduce an unsupported additional chart change just to force the verification result. The remaining behaviour is documented in `lab/FINDINGS.md`, including what I would investigate next.

---

# Part 5 — Written Answer

The migration approach and risk analysis are documented in:

```text
ANSWERS.md
```

The approach is based on running the Gateway API implementation alongside the existing ingress-nginx deployment, migrating workloads incrementally, validating behaviour, and retaining a rollback path until the migration is complete.

---

# What I Deliberately Skipped and the Risk

The main item I deliberately did not complete was the final root-cause identification of the supplied reporter binary's JSON parsing behaviour.

The Kubernetes API and ServiceAccount permissions were independently tested and shown to work, but the reporter continued to report:

```text
parse pod list: unexpected end of JSON input
```

I chose not to make an additional speculative change to the assessment chart without evidence.

**Risk:** the Part 4 verification may still report the reporter-related checks as failing, and the reporter's underlying application-level parsing issue would require additional investigation.

The next diagnostic step would be to capture and compare the exact HTTP request/response made by the reporter binary with the successful request made using the same ServiceAccount, focusing on response-body handling, HTTP transport behaviour, and JSON decoding.

---

# Production-Ready Improvements

For a production deployment, I would extend this submission in several areas.

## Infrastructure and Kubernetes

- Use separate namespaces/environments for development, staging, and production.
- Manage cluster and cloud infrastructure with Terraform.
- Use dedicated IAM identities and least-privilege RBAC.
- Use NetworkPolicies to restrict unnecessary pod-to-pod traffic.
- Configure PodDisruptionBudgets for important workloads.
- Add topology spread constraints or appropriate anti-affinity for highly available replicas.
- Use persistent storage only where application requirements justify it.
- Configure resource requests/limits from measured workload data.
- Use image digests or an approved immutable image promotion process.
- Add image signing and verification where supported.

## CI/CD

A production pipeline would include:

1. Source validation
2. Unit tests
3. Helm lint/template validation
4. Container build
5. Image vulnerability scanning
6. Image push to a private registry
7. Deployment to a non-production environment
8. Automated smoke tests
9. Controlled promotion to production

The optional CI pipeline could also run Trivy and fail on agreed HIGH/CRITICAL findings.

## Observability

I would add:

- Prometheus metrics
- Grafana dashboards
- centralized logs
- application-level health and metrics
- alerting for availability, latency, errors, and resource saturation
- Kubernetes event monitoring

## Security

I would additionally use:

- minimal/distroless images where appropriate
- dependency scanning
- secret management rather than repository-stored secrets
- admission policies
- namespace-level resource quotas
- NetworkPolicies
- least-privilege RBAC
- regular image and dependency updates

---

# Verification Checklist

## Application

```bash
curl http://localhost:3000/
curl http://localhost:3000/health
```

## Helm

```bash
helm lint ./chart
helm template demo ./chart
```

## Kind

```bash
kind get clusters
kubectl cluster-info
```

## Application namespace

```bash
kubectl get all -n demo
kubectl get ingress -n demo
```

## Debug lab

```bash
cd lab
./scenario.sh up
./scenario.sh verify
```

---

# How I Used AI

I used AI assistants, including ChatGPT, during the assignment as a development and debugging aid.

I used AI for:

- reviewing the assignment requirements;
- discussing Kubernetes, Docker, Helm, and shell-script implementation options;
- reviewing YAML and Dockerfile configuration;
- troubleshooting Kubernetes workload behaviour;
- structuring `FINDINGS.md`, `ANSWERS.md`, and this README;
- reviewing the diagnostic approach and identifying additional commands to investigate failures.

I did not treat generated suggestions as evidence. For Part 4, I ran Kubernetes commands against my local cluster and used the resulting output to determine the observed behaviour.

I also corrected AI suggestions when they did not match the actual cluster behaviour. In particular, the reporter's remaining JSON parsing issue was not given a speculative fix simply to make the verification pass.

All final changes were reviewed against the assignment requirements before submission.
