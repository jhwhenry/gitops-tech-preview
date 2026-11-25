# Create a Cluster-Admin User for the ArgoCD Deployment

## Overview

This guide creates a normal OpenShift user and grants it OpenShift `cluster-admin` permission.
The user is intended to log in to ArgoCD (OpenShift GitOps) and perform the GitOps deployment.

The user is added to the OpenShift `cluster-admins` group, which the default OpenShift GitOps
RBAC policy maps to `role:admin`.

## Identity Provider Options

OpenShift supports multiple identity providers (IdPs) for creating users, for example
HTPasswd, LDAP, OpenID Connect (OIDC), GitHub, GitLab, Google, Keystone, Basic
authentication and Request header. See
[Understanding identity provider configuration](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/authentication_and_authorization/understanding-identity-provider)
in the OpenShift documentation.

The steps for creating the cluster-admin user **differ slightly depending on the identity
provider**:

| Step | Depends on the identity provider? |
|------|-----------------------------------|
| Create the user and credentials | **Yes.** HTPasswd uses a local secret. LDAP, OIDC and others use users that already exist in the external directory and need no credentials secret. |
| Configure the identity provider in the `OAuth/cluster` resource | **Yes.** The `type` and its configuration block (`htpasswd`, `ldap`, `openID`, ...) differ. |
| Grant `cluster-admin` and add the user to the `cluster-admins` group | **No.** The same for every provider. The user name must match the name OpenShift assigns (see `mappingMethod` and the provider's preferred-username claim). |

> **This guide uses the HTPasswd identity provider as an example** to create the cluster-admin
> user. If your cluster uses another identity provider, follow your provider's configuration to
> make the user available, then apply [Step 3](#step-3-grant-cluster-admin-permission)
> with that user's name.

> **Why both a ClusterRoleBinding and a group?** Kubernetes RBAC (`cluster-admin`) controls
> what the user can do in the cluster. ArgoCD uses its own RBAC and evaluates OpenShift
> **group** membership. Without group membership, the user can sign in to ArgoCD but has no
> permissions. See [ArgoCD-RBAC-OCP-Groups.md](ArgoCD-RBAC-OCP-Groups.md).

| Item | Value |
|------|-------|
| User | `argocd-admin` |
| Identity provider | `htpasswd-local` (HTPasswd) |
| Credentials secret | `htpass-secret` in `openshift-config` |
| Kubernetes RBAC | `cluster-admin` ClusterRole |
| OpenShift group | `cluster-admins` (mapped to ArgoCD `role:admin`) |

---

## Prerequisites

- `oc` CLI logged in as a cluster administrator (for example `kube:admin`).
- `htpasswd` utility (`httpd-tools` on RHEL, preinstalled on macOS).
- OpenShift GitOps installed, with ArgoCD RBAC policy containing
  `g, cluster-admins, role:admin` and `scopes: [groups]` (the default).

Verify the current RBAC policy:

```bash
oc get argocd openshift-gitops -n openshift-gitops -o jsonpath='{.spec.rbac}{"\n"}'
```

---

## Step 1: Create the Credentials Secret

Generate a random password and store it in a file readable only by you. Do not commit it.

```bash
umask 077
WORKDIR=$(mktemp -d) && cd "$WORKDIR"

PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-20)
htpasswd -c -B -b users.htpasswd argocd-admin "$PASS"
echo "$PASS" > argocd-admin.password

oc create secret generic htpass-secret \
  --from-file=htpasswd=users.htpasswd \
  -n openshift-config
```

To add the user to an existing htpasswd secret instead, extract it, append the user without
`-c`, and replace the secret:

```bash
oc get secret htpass-secret -n openshift-config -o jsonpath='{.data.htpasswd}' | base64 -d > users.htpasswd
htpasswd -B -b users.htpasswd argocd-admin "$PASS"
oc create secret generic htpass-secret --from-file=htpasswd=users.htpasswd \
  -n openshift-config --dry-run=client -o yaml | oc replace -f -
```

---

## Step 2: Add the HTPasswd Identity Provider

Append the provider to the existing list. **Do not replace** `spec.identityProviders`;
that would remove existing providers (for example IBMid) and lock out their users.

```bash
oc get oauth cluster -o jsonpath='{.spec.identityProviders[*].name}{"\n"}'

oc patch oauth cluster --type=json -p '[
  {"op":"add","path":"/spec/identityProviders/-","value":{
    "name":"htpasswd-local",
    "mappingMethod":"claim",
    "type":"HTPasswd",
    "htpasswd":{"fileData":{"name":"htpass-secret"}}}}]'
```

If `spec.identityProviders` is empty or absent, use `{"op":"add","path":"/spec/identityProviders","value":[...]}`.

> **GitOps note:** If the `OAuth/cluster` resource is managed by an ArgoCD Application
> (check the `argocd.argoproj.io/tracking-id` annotation), add the provider in the Git source
> instead, otherwise ArgoCD may revert the change.

The authentication operator redeploys the `oauth-openshift` pods. Wait until it settles:

```bash
oc get co authentication
oc get pods -n openshift-authentication
```

`PROGRESSING` must return to `False` before the user can log in.

---

## Step 3: Grant Cluster Admin Permission

The `User` object is only created at first login, so create the group membership and
the binding by name. A "User not found" warning is expected at this point.

```bash
# Kubernetes RBAC
oc adm policy add-cluster-role-to-user cluster-admin argocd-admin

# ArgoCD RBAC (group membership)
oc adm groups new cluster-admins argocd-admin
```

If the `cluster-admins` group already exists, add the user instead:

```bash
oc adm groups add-users cluster-admins argocd-admin
```

---

## Step 4: Verify

### OpenShift

```bash
API=$(oc whoami --show-server)
KC=$(mktemp)
oc login "$API" -u argocd-admin -p "$(cat argocd-admin.password)" --kubeconfig=$KC

KUBECONFIG=$KC oc whoami                              # argocd-admin
KUBECONFIG=$KC oc auth can-i '*' '*' --all-namespaces # yes
KUBECONFIG=$KC oc get groups                          # cluster-admins   argocd-admin
rm -f $KC
```

### ArgoCD

1. Get the ArgoCD URL:

   ```bash
   oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='https://{.spec.host}{"\n"}'
   ```

2. Open it, click **LOG IN VIA OPENSHIFT**, select the **htpasswd-local** provider, and sign in
   as `argocd-admin`.
3. Confirm **Settings > Projects** and **Applications** are visible and editable.

CLI:

```bash
argocd login <argocd-host> --sso
argocd account can-i create applications '*/*'   # yes
```

---

## Rollback

```bash
oc adm groups remove-users cluster-admins argocd-admin
oc adm policy remove-cluster-role-from-user cluster-admin argocd-admin
oc delete user argocd-admin
oc delete identity htpasswd-local:argocd-admin

# Remove the provider entry (find its index first)
oc get oauth cluster -o jsonpath='{range .spec.identityProviders[*]}{.name}{"\n"}{end}'
oc patch oauth cluster --type=json -p '[{"op":"remove","path":"/spec/identityProviders/<index>"}]'

oc delete secret htpass-secret -n openshift-config
```

Delete `cluster-admins` only if you created it in Step 3 and nothing else uses it.

---

## Security Notes

- `cluster-admin` is the highest privilege. Use this account only for the GitOps installation
  and remove it (see Rollback) when no longer needed.
- Never commit the password or `users.htpasswd` to Git. Delete the working directory after
  you store the password in your secrets manager.
- Rotate the password by regenerating the htpasswd entry and replacing the secret.
- Access to ArgoCD should be over HTTPS only; the OpenShift route already terminates TLS.
- For production, prefer an enterprise identity provider (OIDC/LDAP) with MFA over HTPasswd.
