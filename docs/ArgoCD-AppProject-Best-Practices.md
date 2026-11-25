# ArgoCD AppProject Best Practices for IBM Software Hub

## Overview

This document captures the enterprise-grade AppProject design decisions made for the
IBM Software Hub GitOps deployment on OpenShift. It explains the rationale behind each
configuration choice and provides a reference for extending or adapting the setup.

The AppProject definition lives in
[`appproject/argocd-project.yaml`](../appproject/argocd-project.yaml).
The global RBAC policy lives in
[`appproject/argocd-rbac-cm.yaml`](../appproject/argocd-rbac-cm.yaml).

---

## Why Use an AppProject?

The ArgoCD `default` project places no restrictions on what can be deployed, from where,
to which namespaces, or by whom. For enterprise deployments this is unacceptable:

| Risk without AppProject | How AppProject addresses it |
|---|---|
| Any authenticated user can see all deployment state | `policy.default: ""` + explicit role assignments |
| Any Git repo can supply manifests | `sourceRepos` locked to organisation's repos |
| Applications can deploy to any namespace | `destinations` restricted to declared namespaces |
| Any cluster-scoped resource can be created (e.g. `Node`, `MachineConfig`) | `clusterResourceBlacklist` blocks dangerous kinds |
| No separation of access between platform team and auditors | Project-scoped RBAC roles |

---

## 1. Project Scope — Environment-Agnostic Design

### Best practice
Define **one AppProject per platform**, not one per environment. Environment-specific
behaviour (target cluster, Helm values, chart paths) belongs in the `ApplicationSet`,
not in the AppProject.

### What this repo does
A single `ibm-software-hub` AppProject is shared across `dev` and `prod`. The
`ApplicationSet` in each environment folder references `project: ibm-software-hub`.

### Why
- Reduces operational overhead — no need to maintain `ibm-software-hub-dev` and
  `ibm-software-hub-prod` in sync
- Consistent governance policy across environments
- Adding a new environment (e.g. `staging`) requires only a new `ApplicationSet`,
  not a new AppProject

---

## 2. Source Repositories — Supply Chain Trust Boundary

### Best practice
Lock `sourceRepos` to only the organisation's blessed repositories. Never use `'*'`.

### What this repo does

```yaml
sourceRepos:
  - "https://github.com/jhwhenry/gitops-tech-preview.git"
```

### Why
`sourceRepos` controls `Application.spec.source.repoURL` — the repo or registry that
supplies the Helm charts or raw YAML manifests. A wildcard (`'*'`) means any Git repo,
Helm registry, or OCI registry can supply manifests into the project's destinations,
creating a supply chain injection vector.

### Important distinction
`sourceRepos` governs **chart/manifest content sources only**. It does NOT control where
`Application` or `ApplicationSet` CRs are stored — that is governed by `sourceNamespaces`.

### When adding new sources
Add an entry for every new source type:

```yaml
sourceRepos:
  - "https://github.com/jhwhenry/gitops-tech-preview.git"   # current
  - "oci://cp.icr.io/cp/cpd"                                   # OCI Helm registry
  - "https://artifactory.example.com/helm-local"               # Artifactory Helm repo
```

ArgoCD normalises Git URLs before matching (trailing `.git` differences are handled),
but OCI and HTTP Helm repo URLs are matched **literally**.

---

## 3. Source Namespaces — Application CR Trust Boundary

### Best practice
Lock `sourceNamespaces` to the ArgoCD control-plane namespace only.

### What this repo does

```yaml
sourceNamespaces:
  - openshift-gitops
```

### Why
`sourceNamespaces` controls which Kubernetes namespaces may host `Application` or
`ApplicationSet` CR objects that reference this project. A wildcard (`'*'`) means a
user in any namespace could create an `Application` CR pointing `project: ibm-software-hub`
and push workloads into the project's destinations.

### The two-dimensional trust check

```
sourceRepos       →  WHERE does chart content come from?
                     (Application.spec.source.repoURL)

sourceNamespaces  →  WHERE does the Application CR live?
                     (namespace of the Application object)
```

Both must pass. Locking `sourceNamespaces` to `openshift-gitops` ensures that only
ApplicationSets and bootstrap Applications managed by the GitOps operator itself can
claim membership of this project.

---

## 4. Destinations — Deployment Target Restriction

### Best practice
Enumerate explicit destination namespaces. Never use `namespace: '*'`.

### What this repo does

```yaml
destinations:
  - name: in-cluster
    namespace: cpd-operators
    server: "https://kubernetes.default.svc"
  - name: in-cluster
    namespace: cpd-instance
    server: "https://kubernetes.default.svc"
  - name: in-cluster
    namespace: ibm-licensing
    server: "https://kubernetes.default.svc"
  - name: in-cluster
    namespace: openshift-gitops
    server: "https://kubernetes.default.svc"
  # The generated Applications use 'default' (namespace-scoped charts) or no
  # namespace (cluster-scoped charts) as their destination.
  - name: in-cluster
    namespace: default
    server: "https://kubernetes.default.svc"
  - name: in-cluster
    namespace: ""
    server: "https://kubernetes.default.svc"
```

### Why
A wildcard namespace destination (`namespace: '*'`) allows an application in this project
to deploy resources into **any** namespace on the cluster, including `kube-system`,
`openshift-etcd`, or another team's namespace.

### Use `https://kubernetes.default.svc` for in-cluster
When ArgoCD runs inside the same cluster it manages, always use the in-cluster API server
reference. This avoids external hostname dependency and is consistent with how ArgoCD
registers the local cluster internally.

### When adding new services
Add a destination entry for each new namespace a new IBM Software Hub service requires:

```yaml
  - name: in-cluster
    namespace: <new-service-namespace>
    server: "https://kubernetes.default.svc"
```

---

## 5. Cluster-Scoped Resource Control — Allowlist-All + Blacklist

### Best practice
For an open-ended operator platform like IBM Software Hub, use the
**allowlist-all + blacklist** pattern rather than an explicit whitelist.

### What this repo does

```yaml
clusterResourceWhitelist:
  - group: "*"
    kind: "*"

clusterResourceBlacklist:
  - { group: "",                               kind: "Node"                       }
  - { group: "",                               kind: "PersistentVolume"           }
  - { group: "storage.k8s.io",                kind: "StorageClass"               }
  - { group: "",                               kind: "Namespace"                  }
  - { group: "project.openshift.io",          kind: "Project"                    }
  - { group: "machineconfiguration.openshift.io", kind: "MachineConfig"          }
  - { group: "config.openshift.io",           kind: "ClusterVersion"             }
  - { group: "apiregistration.k8s.io",        kind: "APIService"                 }
  - { group: "scheduling.k8s.io",             kind: "PriorityClass"              }
  - { group: "security.openshift.io",         kind: "SecurityContextConstraints" }
```

### Why the allowlist-all pattern
IBM Software Hub is extensible — each new service (DataStage, Analytics Engine, Cognos,
OpenSearch, etc.) installs CRDs and operator CRs under its own unique API group. An
explicit whitelist would require updating the AppProject every time a new service is
onboarded, creating operational friction and deployment failures.

### Why not `group: '*', kind: '*'` in the whitelist alone (original proposal)
Without a blacklist, this is equivalent to no AppProject isolation at all. The blacklist
is what provides the governance value.

### ArgoCD evaluation logic
```
permitted = isWhiteListed AND NOT isBlackListed
```
**Both fields must be set.** A blacklist with no whitelist has no effect because an
empty whitelist makes `isWhiteListed` always `false`.

### Blacklist category rationale

| Category | Kinds | Why blocked |
|---|---|---|
| Infrastructure primitives | `Node`, `PersistentVolume`, `StorageClass` | Platform infrastructure — must not be managed by application delivery |
| Cluster/project topology | `Namespace`, `Project` | Namespace lifecycle is a platform concern; ArgoCD's `CreateNamespace=true` syncOption handles this separately |
| OpenShift platform controls | `MachineConfig`, `ClusterVersion` | `MachineConfig` modifies node OS directly; `ClusterVersion` controls platform upgrades — catastrophic if misused |
| API server extension | `APIService` | Extends the Kubernetes API server itself |
| Scheduling | `PriorityClass` | Affects cluster-wide pod scheduling priority |
| OpenShift pod privileges | `SecurityContextConstraints` | Defines what pods are allowed to do — cluster-scoped privilege escalation vector |

---

## 6. Namespace-Scoped Resource Control — Allowlist-All + Blacklist

### Best practice
Use the same allowlist-all + blacklist pattern at the namespace level, blocking the
small set of kinds that affect namespace policy rather than individual workloads.

### What this repo does

```yaml
namespaceResourceWhitelist:
  - group: "*"
    kind: "*"

namespaceResourceBlacklist:
  - { group: "networking.k8s.io", kind: "NetworkPolicy" }
  - { group: "",                  kind: "ResourceQuota"  }
  - { group: "",                  kind: "LimitRange"     }
  - { group: "apps",              kind: "DaemonSet"      }
  - { group: "k8s.ovn.org",      kind: "EgressFirewall" }
```

### Blacklist rationale

| Kind | Why blocked |
|---|---|
| `NetworkPolicy` | Network segmentation policy — belongs under a dedicated network security team |
| `ResourceQuota` | Governs how much CPU/memory/storage a namespace may consume — must not be self-set by workloads |
| `LimitRange` | Sets default and maximum resource limits per pod/container — platform governance concern |
| `DaemonSet` | Runs a pod on **every node** — no IBM SWH application chart should deploy node-level daemons |
| `EgressFirewall` | OpenShift OVN egress control — platform networking concern |

### Confirmed safe to blacklist
A scan of all IBM Software Hub Helm chart templates in this repository confirmed that
**none** of the above kinds are created as top-level Kubernetes objects by any chart.
Where `NetworkPolicy` appears in charts (e.g. DataStage `enableNetworkPolicy` field),
it is a configuration flag passed to the operator — the operator creates NetworkPolicies
at runtime through its own controller, not through a chart template.

---

## 7. Orphaned Resource Monitoring

### Best practice
Enable `orphanedResources.warn: true` in all production AppProjects.

### What this repo does

```yaml
orphanedResources:
  warn: true
```

### Why
Orphaned resources are objects that exist in a destination namespace but are not tracked
by any Argo CD application. This is an important audit signal — it can indicate:
- Manual changes made outside GitOps (drift)
- Resources left behind after an application was deleted
- Namespace contamination from a previous installation

With `warn: true`, ArgoCD reports these in the UI without taking any action.

---

## 8. Project Finalizer — Deletion Protection

### Best practice
Always add the `resources-finalizer.argocd.argoproj.io` finalizer to the AppProject.

### What this repo does

```yaml
metadata:
  finalizers:
    - resources-finalizer.argocd.argoproj.io
```

### Why
Without this finalizer, the AppProject CR can be deleted while Applications still
reference it, leaving those Applications in an orphaned state that can be difficult
to recover. The finalizer prevents deletion until all referencing Applications are
removed first.

---

## 9. RBAC — Two-Role Model for Manual and Automated Sync

### Best practice
Design RBAC roles around **actual human interactions**, not hypothetical ones.
In a GitOps deployment, most users are observers, not operators.

### Actor model for IBM Software Hub

The Argo CD based IBM Software Hub services can be synchronized **manually** (the
Applications stay `OutOfSync` until someone syncs them in the Argo CD UI or with
`argocd app sync`) or **automatically** (`syncPolicy.automated`). The RBAC model supports
both. Three actor types exist:

| Actor | OpenShift Group | Access level | Rationale |
|---|---|---|---|
| **Platform Admin** | `ibm-swh-platform` | `role:admin` (global) | Manages ArgoCD infrastructure: AppProject, clusters, repo registrations, RBAC |
| **SWH Admin** | `ibm-swh-admins` | `swh-admin` (project-scoped) | Full control within `ibm-software-hub` project: application lifecycle, force-sync, ApplicationSet management |
| **Auditor / Viewer** | `ibm-swh-viewers` | `swh-readonly` (project-scoped) | Read-only visibility for compliance, security teams, management |

### Why there is no "deployer" role
A deployer role (sync-only) is absent by design:
1. **Whoever syncs needs full access** — in manual mode the person who triggers the sync, and in automated mode the person who fixes a failed sync, needs logs, the resource tree, and the ability to force-sync or modify the ApplicationSet. That is `swh-admin`.
2. **False safety** — a sync-only role lets the user press a button but not understand or fix the failure

If your organisation separates duties, add your own project role with only `applications, sync`.

### Role definitions

**`swh-readonly`** — for auditors, compliance teams, management:
```yaml
policies:
  - p, proj:ibm-software-hub:swh-readonly, applications, get, ibm-software-hub/*, allow
  - p, proj:ibm-software-hub:swh-readonly, logs,          get, ibm-software-hub/*, allow
```

**`swh-admin`** — for IBM SWH platform team:
```yaml
policies:
  - p, proj:ibm-software-hub:swh-admin, applications,    *,   ibm-software-hub/*, allow
  - p, proj:ibm-software-hub:swh-admin, applicationsets, *,   ibm-software-hub/*, allow
  - p, proj:ibm-software-hub:swh-admin, logs,            get, ibm-software-hub/*, allow
  - p, proj:ibm-software-hub:swh-admin, repositories,    get, *,                 allow
```

---

## 10. Global RBAC — Default Policy and Group Isolation

### Best practice
Set `policy.default: ""` in enterprise deployments. Never use `role:readonly` as the default.

### What this repo does

```yaml
# argocd-rbac-cm.yaml
policy.default: ""
policy.csv: |
  g, ibm-swh-platform, role:admin
  g, ibm-swh-admins,   role:proj:ibm-software-hub:swh-admin
  g, ibm-swh-viewers,  role:proj:ibm-software-hub:swh-readonly
scopes: '[groups]'
```

### Why `policy.default: ""`
The ArgoCD documentation warns:
> *"All authenticated users get at least the permissions granted by the default policies.
> This access cannot be blocked by a `deny` rule."*

With `policy.default: role:readonly` (the common default), every authenticated OpenShift
user can see all IBM Software Hub application state, manifests, sync history, and Helm
values — including sensitive configuration. Setting it to `""` means unmapped users
see nothing.

### Why `scopes: '[groups]'` is required
ArgoCD evaluates **OpenShift group membership**, not ClusterRoleBindings. A user with
`cluster-admin` ClusterRoleBinding but no OpenShift `Group` membership will have
`"groups": null` in their token and will be treated as having no ArgoCD access.
See [ArgoCD-RBAC-OCP-Groups.md](ArgoCD-RBAC-OCP-Groups.md) for the full setup guide.

---

## 11. Deployment Order

The AppProject must exist before the ApplicationSets that reference it.

```bash
cd $ARGOCD_DIR/gitops-tech-preview

# Step 1 — Apply the global RBAC ConfigMap
oc apply -f appproject/argocd-rbac-cm.yaml

# Step 2 — Apply the AppProject (update sourceRepos and destinations first)
oc apply -f appproject/argocd-project.yaml

# Step 3 — Apply the ApplicationSets (see Install.md, section 3.19)
```

Steps 1 and 2 are one-time manual operations. Re-apply the files with `oc apply` whenever
you change them.

---

## 12. Validation

Use the ArgoCD CLI to validate policies before applying to a live cluster:

```bash
# Validate policy syntax
argocd admin settings rbac validate \
  --policy-file appproject/argocd-rbac-cm.yaml

# Test specific permissions
argocd admin settings rbac can \
  ibm-swh-viewers applications get ibm-software-hub/cpd-platform-dev \
  --policy-file appproject/argocd-rbac-cm.yaml

argocd admin settings rbac can \
  ibm-swh-admins applications sync ibm-software-hub/cpd-platform-dev \
  --policy-file appproject/argocd-rbac-cm.yaml

# Confirm viewers CANNOT sync
argocd admin settings rbac can \
  ibm-swh-viewers applications sync ibm-software-hub/cpd-platform-dev \
  --policy-file appproject/argocd-rbac-cm.yaml
# expected: No
```

---

## Quick Reference — Configuration Decisions

| Field | Value | Pattern | Rationale |
|---|---|---|---|
| `sourceRepos` | Explicit repo URLs | Locked | Supply chain trust boundary |
| `sourceNamespaces` | `openshift-gitops` only | Locked | Application CR hosting boundary |
| `destinations` | Explicit namespace list | Locked | Prevents cross-namespace deployment |
| `clusterResourceWhitelist` | `group: *, kind: *` | Allowlist-all | IBM SWH adds new CRD groups per service |
| `clusterResourceBlacklist` | 10 explicit kinds | Targeted blacklist | Platform infrastructure must not be app-managed |
| `namespaceResourceWhitelist` | `group: *, kind: *` | Allowlist-all | Operators need broad namespace access |
| `namespaceResourceBlacklist` | 5 explicit kinds | Targeted blacklist | Policy kinds must not be self-managed by workloads |
| `orphanedResources` | `warn: true` | Monitoring | Detects manual drift and orphaned resources |
| `finalizers` | `resources-finalizer` | Protection | Prevents accidental deletion |
| `policy.default` | `""` | Deny-by-default | No implicit access for unmapped users |
| RBAC roles | 2 (readonly + admin) | Minimal | Matches actual human interactions in both manual and automated sync |

---

## Related Files

| File | Purpose |
|---|---|
| [`appproject/argocd-project.yaml`](../appproject/argocd-project.yaml) | AppProject definition |
| [`appproject/argocd-rbac-cm.yaml`](../appproject/argocd-rbac-cm.yaml) | Global ArgoCD RBAC ConfigMap |
| [`docs/ArgoCD-RBAC-OCP-Groups.md`](ArgoCD-RBAC-OCP-Groups.md) | Step-by-step RBAC setup guide with OpenShift groups |
| [`Install.md`](Install.md) | Installation guide — section 3.13 applies the AppProject, section 3.19 applies the ApplicationSets |
| [`ArgoCD-AppProject-RBAC-Test-Guide.md`](ArgoCD-AppProject-RBAC-Test-Guide.md) | Hands-on lab to test the AppProject and RBAC with test users and groups |
