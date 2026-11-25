# Scale Argo CD

## Overview

When you start deploying IBM Software Hub, many Argo CD Applications sync at the same time.
This can overwhelm the Argo CD application controller pod. Without scaling, the pod can be
**OOMKilled** (out of memory) and restart.

This guide increases the CPU and memory limits of the application controller to avoid pod
restarts. It uses the default Argo CD instance `openshift-gitops` in the `openshift-gitops`
project, as in [Install.md](Install.md).

---

## Prerequisites

- `oc` CLI logged in as a cluster administrator. See
  [Create-Cluster-Admin-ArogCD-Deployment.md](Create-Cluster-Admin-ArogCD-Deployment.md).
- OpenShift GitOps installed, with the `openshift-gitops` Argo CD instance.
- Enough free CPU and memory on a worker node for the new limits.

---

## Step 1: Check the Current Resources

```bash
oc get argocd openshift-gitops -n openshift-gitops -o jsonpath='{.spec.controller.resources}{"\n"}'
```

Note the values so you can compare them or roll back. If your current limits are already
higher than the values in Step 2, do not lower them.

---

## Step 2: Increase the Controller Limits

```bash
oc patch argocd openshift-gitops -n openshift-gitops --type=merge -p '{
  "spec": {
    "controller": {
      "resources": {
        "limits": {
          "cpu": "4",
          "memory": "16Gi"
        }
      }
    }
  }
}'
```

| Setting | Value |
|---------|-------|
| `limits.cpu` | `4` |
| `limits.memory` | `16Gi` |

The merge patch changes only the limits. Existing `requests` are kept. The OpenShift GitOps
operator reconciles the `ArgoCD` resource and restarts the `openshift-gitops-application-controller`
StatefulSet pod with the new values.

> **Sizing:** Treat these values as a starting point. Increase them further if the controller is
> still OOMKilled during large syncs, and make sure a node can schedule the pod.

---

## Step 3: Verify

Wait for the controller pod to restart and become ready:

```bash
oc rollout status statefulset/openshift-gitops-application-controller -n openshift-gitops
oc get pods -n openshift-gitops | grep application-controller
```

Confirm the new limits are applied to the running StatefulSet:

```bash
oc get statefulset openshift-gitops-application-controller -n openshift-gitops \
  -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

During a large deployment, check that the pod is not being restarted or OOMKilled:

```bash
oc get pod openshift-gitops-application-controller-0 -n openshift-gitops \
  -o jsonpath='{.status.containerStatuses[0].restartCount}{" "}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}'
oc adm top pod -n openshift-gitops
```

A `restartCount` that keeps growing with reason `OOMKilled` means the memory limit is still
too low.

---

## Rollback

Set the limits back to the values you noted in Step 1, for example:

```bash
oc patch argocd openshift-gitops -n openshift-gitops --type=merge -p '{
  "spec": {"controller": {"resources": {"limits": {"cpu": "<old-cpu>", "memory": "<old-memory>"}}}}
}'
```

---

## Notes

- Changing the limits restarts the application controller. Apply it before a large deployment
  or when no sync is in progress.
- If the `ArgoCD` resource is managed in Git, make the same change in the Git source. Otherwise
  Argo CD may revert it.
- Make sure the memory `requests` are not higher than the new `limits`.
