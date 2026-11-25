# Setting ArgoCD RBAC with OpenShift Groups

## Overview

This guide explains how to configure ArgoCD RBAC for the IBM Software Hub GitOps deployment
using OpenShift group membership. It covers the actor model, role design rationale, and the
complete setup from creating OpenShift groups through to verifying effective permissions.

---

## Why Kubernetes ClusterRoleBinding Is Not Enough

A common misconception is that a user with `cluster-admin` ClusterRoleBinding automatically
has full access to ArgoCD. In practice, the user may still be **unable to see the AppProject**
in the ArgoCD Settings UI.

**Root cause:** ArgoCD uses its **own internal RBAC system** (`spec.rbac` in the `ArgoCD` CR),
entirely separate from Kubernetes RBAC. With the default OpenShift GitOps configuration,
ArgoCD evaluates **OpenShift group membership** — not ClusterRoleBindings.

The default ArgoCD RBAC policy on OpenShift GitOps is:

```
g, system:cluster-admins, role:admin
g, cluster-admins,        role:admin
```

With `scopes: ["groups"]` set, ArgoCD only recognises users who belong to a named
OpenShift `Group` object. If a user has no group membership (`"groups": null`), ArgoCD
treats them as having no access regardless of their Kubernetes privileges.

> **Key principle:** A Kubernetes ClusterRoleBinding alone is insufficient.
> ArgoCD needs the user to be a member of a named OpenShift `Group` object.

> **Exception — core mode:** `argocd login --core` (used in [Install.md](Install.md),
> section 3.6) does not call the Argo CD server. The CLI uses your kubeconfig identity and
> reads and writes the Argo CD custom resources directly, so only Kubernetes RBAC applies and
> the Argo CD RBAC in this guide is bypassed. Use core mode only for the installation by
> cluster administrators. For day-to-day operations, use `argocd login <server> --sso`.

---

## Actor Model — IBM Software Hub GitOps Deployment

The Argo CD based IBM Software Hub services can be synchronized in **either** of two ways.
The RBAC model in this guide supports both:

| Sync mode | How it works | Who acts |
|---|---|---|
| **Manual sync** | The Applications stay `OutOfSync` until someone syncs them (Argo CD UI or `argocd app sync`). The installation guide ([Install.md](Install.md)) uses this mode and syncs the cluster-scoped Applications before the namespace-scoped ones. | A person with the `sync` permission on the Applications: `swh-admin` or `role:admin` |
| **Automated sync** | Argo CD syncs whenever the Git or Helm content changes (`syncPolicy.automated`, optionally with `selfHeal`). The deployment is driven by commits. | No one triggers syncs. People only monitor, and intervene when a sync fails. |

The same three actor types exist in both modes. Only the day-to-day activity of the
**SWH Admin** differs: it triggers syncs in manual mode and troubleshoots in automated mode.

| Actor | OpenShift Group | What they need | ArgoCD role |
|---|---|---|---|
| **Platform Admin** | `ibm-swh-platform` | Full global ArgoCD control: manage AppProject, ApplicationSets, repo registrations, clusters, certificates | `role:admin` (global) |
| **SWH Admin** | `ibm-swh-admins` | Full IBM SWH project-scoped control: application lifecycle, manual sync / force-sync, ApplicationSet management, logs | `swh-admin` (project) |
| **Auditor / Viewer** | `ibm-swh-viewers` | Read-only visibility: app health, sync status, manifests, pod logs. Cannot sync. | `swh-readonly` (project) |

> **Why there is no sync-only "deployer" role:**
> Whoever triggers a manual sync, or intervenes in a failed automated sync, needs **full
> diagnostic access** — logs, resource tree, force-sync, and the ability to modify the
> ApplicationSet if needed. That is the `swh-admin` role, not a restricted sync-only role.
> A sync-only role would create false safety: the user can press Sync but cannot see why it
> fails or fix the root cause.
>
> If your organisation separates duties, you can add your own project role with only
> `applications, sync` to the `roles` section of `argocd-project.yaml`.

---

## How the Two Layers Work Together

```
Layer 1 — argocd-rbac-cm.yaml (global policy):
  Controls policy.default, platform-admin access, and group→role mappings.

Layer 2 — argocd-project.yaml (AppProject roles):
  Defines what swh-readonly and swh-admin can do within ibm-software-hub.

Together:
  OpenShift Group object      →  oc adm groups new / add-users
          ↓
  argocd-rbac-cm.yaml         →  g, <group>, role:proj:ibm-software-hub:<role>
          ↓
  argocd-project.yaml roles   →  policies for swh-readonly / swh-admin
          ↓
  ArgoCD RBAC scope           →  ArgoCD CR spec.rbac.scopes: "[groups]"
          ↓
  User sees AppProject        →  ArgoCD UI → Settings → Projects
```

All layers must be in place. A gap at any layer results in the same symptom:
the AppProject is invisible or inaccessible to the user.

---

## Role Definitions

Defined in [`appproject/argocd-project.yaml`](../appproject/argocd-project.yaml):

| Role | Resource | Actions | Intended audience |
|---|---|---|---|
| `swh-readonly` | `applications` | `get` | Auditors, compliance teams, management |
| `swh-readonly` | `logs` | `get` | Auditors, compliance teams, management |
| `swh-admin` | `applications` | `*` (all) | IBM SWH platform team |
| `swh-admin` | `applicationsets` | `*` (all) | IBM SWH platform team |
| `swh-admin` | `logs` | `get` | IBM SWH platform team |
| `swh-admin` | `repositories` | `get` | IBM SWH platform team |

Global `role:admin` (assigned to `ibm-swh-platform` via `argocd-rbac-cm.yaml`) additionally
covers: clusters, projects, certificates, GPG keys, accounts, and global ArgoCD configuration.

---

## Step-by-Step Setup

### Step 1 — Create the OpenShift Groups

ArgoCD requires the groups to exist as real OpenShift `Group` objects. LDAP group claims
or ClusterRoleBindings alone are not sufficient.

```bash
# Create the three groups
oc adm groups new ibm-swh-platform
oc adm groups new ibm-swh-admins
oc adm groups new ibm-swh-viewers

# Add users to each group
oc adm groups add-users ibm-swh-platform  platform-admin@example.com
oc adm groups add-users ibm-swh-admins    swh-admin@example.com
oc adm groups add-users ibm-swh-viewers   auditor@example.com
```

Verify group membership:

```bash
oc get group ibm-swh-platform -o json | jq '.users'
oc get group ibm-swh-admins   -o json | jq '.users'
oc get group ibm-swh-viewers  -o json | jq '.users'
```

---

### Step 2 — Wire Groups into the AppProject

Populate the `groups: []` fields in
[`argocd-project.yaml`](../appproject/argocd-project.yaml):

```yaml
roles:
  - name: swh-readonly
    description: >
      Read-only visibility into IBM Software Hub deployment state.
      For auditors, compliance teams, and management.
    policies:
      - p, proj:ibm-software-hub:swh-readonly, applications, get, ibm-software-hub/*, allow
      - p, proj:ibm-software-hub:swh-readonly, logs,          get, ibm-software-hub/*, allow
    groups:
      - ibm-swh-viewers          # OpenShift Group name from Step 1

  - name: swh-admin
    description: >
      Full application management for IBM Software Hub platform team.
      Includes ApplicationSet control and force-sync capability.
    policies:
      - p, proj:ibm-software-hub:swh-admin, applications,    *,   ibm-software-hub/*, allow
      - p, proj:ibm-software-hub:swh-admin, applicationsets, *,   ibm-software-hub/*, allow
      - p, proj:ibm-software-hub:swh-admin, logs,            get, ibm-software-hub/*, allow
      - p, proj:ibm-software-hub:swh-admin, repositories,    get, *,                 allow
    groups:
      - ibm-swh-admins           # OpenShift Group name from Step 1
```

Argo CD reads the `groups:` of a project role directly from the AppProject when it
evaluates a request. It does **not** write them into `argocd-rbac-cm`. A group can
therefore be bound to a project role in either place, with the same effect:

- in the `groups:` field of the role in `argocd-project.yaml` (this step), or
- with a `g, <group>, role:proj:ibm-software-hub:<role>` line in `policy.csv` of
  `argocd-rbac-cm` (Step 3).

The provided [`argocd-rbac-cm.yaml`](../appproject/argocd-rbac-cm.yaml) already contains the
`g, ...` lines for `ibm-swh-admins` and `ibm-swh-viewers`. If you use it as is, you can leave
`groups: []` empty here. Use one place as the single source of truth to avoid confusion.

Apply the updated `argocd-project.yaml` in Step 5.

---

### Step 3 — Apply the Global RBAC ConfigMap

Apply the companion
[`argocd-rbac-cm.yaml`](../appproject/argocd-rbac-cm.yaml)
which sets `policy.default: ""` and maps the platform admin group to `role:admin`:

```bash
cd $ARGOCD_DIR/gitops-tech-preview
oc apply -f appproject/argocd-rbac-cm.yaml
```

> **Note:** On OpenShift GitOps, the operator may manage `argocd-rbac-cm` from `spec.rbac`
> in the `ArgoCD` custom resource and revert manual changes to the ConfigMap. If your
> changes disappear, set `policy.csv`, `policy.default` and `scopes` in `spec.rbac` of the
> `ArgoCD` CR (`oc edit argocd openshift-gitops -n openshift-gitops`) instead.

This configures:
- `policy.default: ""` — no access for unauthenticated or unmapped users
- `g, ibm-swh-platform, role:admin` — global ArgoCD admin for platform team
- `scopes: '[groups]'` — evaluates OpenShift group membership

> **Important:** `policy.default: ""` means any authenticated user with no group membership
> sees nothing in ArgoCD. This is intentional — it prevents IBM Software Hub deployment
> state from being visible to all OpenShift cluster users.

---

### Step 4 — Verify the ArgoCD RBAC Scope Includes Groups

Check that the `ArgoCD` CR has `scopes` set to `[groups]`:

```bash
oc get argocd openshift-gitops -n openshift-gitops \
  -o jsonpath='{.spec.rbac.scopes}{"\n"}'
```

Expected output:

```
[groups]
```

If the field is missing or empty, patch it:

```bash
oc patch argocd openshift-gitops -n openshift-gitops \
  --type=merge \
  -p '{"spec":{"rbac":{"scopes":"[groups]"}}}'
```

> **Important:** Without this setting, ArgoCD will never evaluate group membership.
> All users will fall through to `policy.default`.

---

### Step 5 — Apply the AppProject to the Cluster

Apply the AppProject before the ApplicationSets are applied
(see [Install.md](Install.md), section 3.13). Update `sourceRepos` and `destinations`
in the file first.

```bash
cd $ARGOCD_DIR/gitops-tech-preview
oc apply -f appproject/argocd-project.yaml
```

Verify the project is visible in ArgoCD:

```bash
oc get appproject ibm-software-hub -n openshift-gitops
argocd proj list
# NAME                 DESCRIPTION
# ibm-software-hub     IBM Software Hub GitOps project. Governs the Argo CD Applications that deploy the CPD platform, CPFS operators, IBM Licensing, ...
```

---

### Step 6 — Validate Policies Before Going Live

Use the ArgoCD CLI to verify policies are correct before users attempt to log in:

```bash
# Validate policy syntax
argocd admin settings rbac validate \
  --policy-file appproject/argocd-rbac-cm.yaml

# Test whether ibm-swh-viewers can get applications
argocd admin settings rbac can \
  ibm-swh-viewers applications get ibm-software-hub/cpd-platform-dev \
  --policy-file appproject/argocd-rbac-cm.yaml

# Test whether ibm-swh-admins can sync applications
argocd admin settings rbac can \
  ibm-swh-admins applications sync ibm-software-hub/cpd-platform-dev \
  --policy-file appproject/argocd-rbac-cm.yaml
```

---

### Step 7 — Verify a User's Effective Permissions

Log in to the Argo CD server with SSO as the user you want to test, then verify the
resolved group membership and roles. Do **not** use `argocd login --core` for this: core
mode bypasses Argo CD authentication and RBAC, so `get-user-info` prints `Logged In: false`.

```bash
ARGOCD_HOST=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')

# Use a separate CLI config so the --core context used for the installation is kept
argocd login $ARGOCD_HOST --sso --grpc-web --config /tmp/argocd-sso.json

# Check what ArgoCD sees for the logged-in user
argocd account get-user-info --config /tmp/argocd-sso.json
```

Remove `/tmp/argocd-sso.json` when you are done, because it holds a session token.

Expected output when groups are correctly wired:

```json
{
  "loggedIn": true,
  "username": "auditor@example.com",
  "groups": ["ibm-swh-viewers"]
}
```

If `groups` is `null` or empty, the user is not a member of any OpenShift `Group` object.
Return to Step 1.

Check the user's effective RBAC permissions:

```bash
argocd proj role list ibm-software-hub --config /tmp/argocd-sso.json
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| AppProject not visible in UI | User has no OpenShift group membership | Add user to an OpenShift Group (Step 1) |
| `"groups": null` in user info | ArgoCD scope not set to `[groups]` | Patch the ArgoCD CR (Step 4) |
| Group exists but user still denied | Group name mismatch between OpenShift Group and `argocd-rbac-cm` | Ensure exact name match — case-sensitive |
| User sees nothing despite correct group | `policy.default: ""` — user's group not mapped in `argocd-rbac-cm` | Add group mapping to `argocd-rbac-cm.yaml` (Step 3) |
| ArgoCD RBAC changes not taking effect | `argocd-rbac-cm` not refreshed | Restart ArgoCD server: `oc rollout restart deployment/openshift-gitops-server -n openshift-gitops` |
| `swh-admin` cannot modify AppProject | AppProject changes require `role:admin` — use `ibm-swh-platform` group | Add user to `ibm-swh-platform` group instead |

---

## Reference — ArgoCD RBAC Policy Format

Every policy line follows this format:

```
p, <subject>,  <resource>,    <action>,  <object>,               <effect>
p, proj:ibm-software-hub:swh-readonly, applications, get, ibm-software-hub/*, allow
```

| Segment | Allowed values |
|---|---|
| `resource` | `applications`, `applicationsets`, `repositories`, `clusters`, `logs`, `exec`, `projects` |
| `action` | `get`, `sync`, `create`, `update`, `delete`, `override`, `action`, `*` |
| `object` | `<project>/<app-name>` — glob patterns supported |
| `effect` | `allow`, `deny` |

Full resource/action matrix from ArgoCD documentation:

| Resource | get | create | update | delete | sync | override |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `applications` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `applicationsets` | ✅ | ✅ | ✅ | ✅ | — | — |
| `repositories` | ✅ | ✅ | ✅ | ✅ | — | — |
| `clusters` | ✅ | ✅ | ✅ | ✅ | — | — |
| `logs` | ✅ | — | — | — | — | — |
| `exec` | — | ✅ | — | — | — | — |

---

## Related Files

| File | Purpose |
|---|---|
| [`appproject/argocd-project.yaml`](../appproject/argocd-project.yaml) | AppProject — role definitions and group bindings |
| [`appproject/argocd-rbac-cm.yaml`](../appproject/argocd-rbac-cm.yaml) | Global ArgoCD RBAC ConfigMap — policy.default and group→role mappings |
| [`Install.md`](Install.md) | Installation guide — section 3.13 applies the AppProject, section 3.19 applies the ApplicationSets |
| [`ArgoCD-AppProject-RBAC-Test-Guide.md`](ArgoCD-AppProject-RBAC-Test-Guide.md) | Hands-on lab to test the AppProject and RBAC with test users and groups |
