# Findings — Part 4 debug lab

Fill in one entry per defect you find. Paste the *actual* output you saw —
we cross-check it against your session recording and your git diff, and the
diagnostic path matters more to us than the fix itself.

Before you start investigating, begin recording:
`script -q part4-session.log` (or `asciinema rec part4-session.cast`), and
commit that file alongside this one.

---

## Defect 1

**Symptom** (what you observed — paste the real command output):

**Cause** (the actual root cause, not the symptom restated):

**Fix** (what you changed, and why this over alternatives):

**How I found it** (the sequence of commands/reasoning that led you here):

---



## Defect 2

**Symptom:** The second issue was migration Job could not be created successfully because its Pod template specified an invalid restart policy.

**Cause:** The workload is a Kubernetes Job, and the Job's Pod template used restartPolicy: Always. A Job Pod must use a supported completion-oriented restart policy rather than Always.

**Fix:** i change form restartPolicy: Always to restartPolicy: OnFailure

## **How I found it:** I started the supplied lab scenario and the migration workload failed during creation time  the job configuration and identified the invalid Pod.



## Defect 3

**Symptom:**The reporter/container security configuration was incompatible with the container image's configured user.
The supplied image was configured with:Config.User = nonroot while the Kubernetes security configuration required the container to run
as non-root.
**Cause:** The image uses the symbolic user nonroot, while the Kubernetes
runAsNonRoot validation requires Kubernetes to be able to establish that
the configured container user is non-zero.

**Fix:**
Configured the workload with an explicit non-root UID/GID:
securityContext:
  runAsUser: 65532
  runAsGroup: 65532
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
**How I found it:**
I inspected the workload security configuration and the supplied image.
I inspected the workload security configuration and the supplied image.

The image was:

docker.io/ebinterview/eb-debug-app:1.0.1

I inspected the image metadata and found:

Config.User = nonroot

I then compared that with the Kubernetes security context requiring
non-root execution.

## I changed the workload to an explicit numeric non-root UID/GID and
retained the other security hardening settings



## Defect 4

**Symptom:** The metrics workload could not satisfy the namespace resource constraints.

**Cause:** The namespace LimitRange had a maximum CPU limit of 1 CPU.
and the metrics container's CPU limit of 4 exceeded the namespace
maximum and the workload could not be admitted with those resource values

**Fix:** i Reduced the metrics workload resources to:  cpu: "500m"
**How I found it:**
I ran the lab and observed that the metrics workload was not becoming
Ready.

I inspected the namespace resource constraints and compared them with the
metrics workload's resource configuration.

## The namespace maximum CPU was: 1



## Defect 5

**Symptom:**The worker workload could not operate correctly with the configured
read-only root filesystem.
The application required access to: /var/cache/app for the cache

**Cause:**The container was configured with: readOnlyRootFilesystem: true but /var/cache/app was part of the container's writable filesystem. Because the root filesystem was read-only, the application could not create
or modify its cache directory.

**Fix:**
Added an emptyDir volume and mounted it at the application's cache path:

volumeMounts:

- name: app-cache
mountPath: /var/cache/app

**How I found it:** I observed that the worker workload was not becoming Ready.

I inspected the worker Pod and its container configuration and identified
that the root filesystem was configured as read-only.

I then identified that the application required:

/var/cache/app

## for its cache.



## Defect 6

**Symptom:** The gateway workload could not successfully communicate with the backend
using the configured backend URL. 

**Cause:**
The backend Service was in the debug-lab namespace, not the default
namespace.  and the host name backend.default.svc
**Fix:** Changed the backend URL to:http://backend:8080

The short Kubernetes Service name resolves to the Service in the same
namespace as the gateway workload.
I used the short Service name instead of hard-coding another namespace,
because both workloads are deployed into the same namespace.

**How I found it:** I inspected the gateway configuration and found
I checked the backend Service namespace and confirmed that it was deployed
in debug-lab.

---

If you ran out of time on any defect, say so here and describe what you would
have tried next — that section is read carefully and counts in your favour.