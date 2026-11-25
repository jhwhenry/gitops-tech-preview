# Argo CD ApplicationSet-Based IBM Software Hub Services Installation

## Table of contents

- [1. Introduction](#1-introduction)
- [2. Prerequisites](#2-prerequisites)
  - [Infrastructure](#infrastructure)
  - [Setting up client workstation](#setting-up-client-workstation)
  - [Access & credentials](#access--credentials)
  - [Governance & authorization](#governance--authorization)
  - [Mirroring images](#mirroring-images)
  - [Cluster preparation](#cluster-preparation)
- [3. Step-by-step deployment procedures](#3-step-by-step-deployment-procedures)
  - [3.1 Set up workstation](#31-set-up-workstation)
  - [3.2 Creating an environment variables file](#32-creating-an-environment-variables-file)
  - [3.3 Start up olm-utils-premium-v4 container](#33-start-up-olm-utils-premium-v4-container)
  - [3.4 Log into the OCP cluster](#34-log-into-the-ocp-cluster)
  - [3.5 Configure Argo CD instance to incorporate custom health checks for IBM Software Hub](#35-configure-argo-cd-instance-to-incorporate-custom-health-checks-for-ibm-software-hub)
  - [3.6 Argo CD repository registration](#36-argo-cd-repository-registration)
  - [3.7 Create namespaces](#37-create-namespaces)
  - [3.8 Grant Argo CD access](#38-grant-argo-cd-access)
  - [3.9 Create an image pull secret](#39-create-an-image-pull-secret)
  - [3.10 Download the CASE packages](#310-download-the-case-packages)
  - [3.11 Clone the `gitops-charts` Helm repo to your local workstation](#311-clone-the-gitops-charts-helm-repo-to-your-local-workstation)
  - [3.12 Clone the `gitops-tech-preview` git repo to your local workstation](#312-clone-the-gitops-tech-preview-git-repo-to-your-local-workstation)
  - [3.13 Apply the AppProject](#313-apply-the-appproject)
  - [3.14 Create install-options.yaml](#314-create-install-optionsyaml)
  - [3.15 Run create-argo-appsets command to create Argo CD applicationsets](#315-run-create-argo-appsets-command-to-create-argo-cd-applicationsets)
  - [3.16 Prepare Helm charts and push them to the Helm repo](#316-prepare-helm-charts-and-push-them-to-the-helm-repo)
  - [3.17 Generate the ibm-licensing Helm values configuration file](#317-generate-the-ibm-licensing-helm-values-configuration-file)
  - [3.18 Commit and push applicationset manifests and helm values configuration files to Git repo](#318-commit-and-push-applicationset-manifests-and-helm-values-configuration-files-to-git-repo)
  - [3.19 Apply ApplicationSets](#319-apply-applicationsets)
- [4. Monitor ApplicationSet Generation](#4-monitor-applicationset-generation)
  - [4.1 Check ApplicationSets status](#41-check-applicationsets-status)
  - [4.2 Check generated Applications](#42-check-generated-applications)
  - [4.3 Watch Applications in real-time](#43-watch-applications-in-real-time)

## 1. Introduction

This document describes, step by step, how to install IBM Software Hub services by using Argo CD ApplicationSet.
We will use release 5.4.0 patch 8 for DataStage and Orchestration Pipelines installation as an example.

**Note:** Argo CD based deployment requires IBM Software Hub Premium entitlement.

The procedure has six stages:

1. Prepare the workstation and the variables file ([3.1](#31-set-up-workstation) to [3.4](#34-log-into-the-ocp-cluster)).
2. Connect Argo CD to the cluster, the repositories and the registry ([3.5](#35-configure-argo-cd-instance-to-incorporate-custom-health-checks-for-ibm-software-hub) to [3.9](#39-create-an-image-pull-secret)).
3. Download the CASE packages and clone the Helm repo and the Git repo ([3.10](#310-download-the-case-packages) to [3.12](#312-clone-the-gitops-tech-preview-git-repo-to-your-local-workstation)).
4. Apply the AppProject and generate the ApplicationSets and values files ([3.13](#313-apply-the-appproject) to [3.15](#315-run-create-argo-appsets-command-to-create-argo-cd-applicationsets)).
5. Publish the Helm charts to your Helm repo and generate the licensing values file ([3.16](#316-prepare-helm-charts-and-push-them-to-the-helm-repo) to [3.17](#317-generate-the-ibm-licensing-helm-values-configuration-file)).
6. Commit the generated files, apply the ApplicationSets and sync the Applications ([3.18](#318-commit-and-push-applicationset-manifests-and-helm-values-configuration-files-to-git-repo) to [3.19](#319-apply-applicationsets)).

Two different repositories are used. Do not confuse them:

| Repository | Example | What it holds | Variable |
|---|---|---|---|
| Helm chart repository | `gitops-charts` | The chart `.tgz` files and `index.yaml` | `HELM_REPO_URL` |
| Git repository for ApplicationSets | `gitops-tech-preview` | The tools, the AppProject manifest, the generated ApplicationSets and the values files | `ARGOCD_APPSET_CONFIG_GIT_REPO_URL` |

## 2. Prerequisites

### Infrastructure
| Requirement | Notes |
|---|---|
|[OpenShift cluster](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=requirements-software#platform__ocp__title__1)| IBM Software Hub supports only the specified releases of Red Hat OpenShift Container Platform. |
| [Storage requirements](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=requirements-storage#control-plane-persistent-stg__title__1) | IBM Software Hub supports and is optimized for several types of persistent storage. Refer to the link for more details.|
| Private image registry | A private image registry must be available, reachable from the cluster, and [pre-populated with all required images](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=prufpcr-mirroring-images-private-container-registry). |
| Helm chart repository | A Helm repository (an `index.yaml` and the chart `.tgz` files, for example `gitops-charts`) that the cluster's Argo CD can reach. The charts extracted from the CASE packages are pushed here in [3.16](#316-prepare-helm-charts-and-push-them-to-the-helm-repo). |
| Git repository for ApplicationSets | A Git repository (for example `gitops-tech-preview`) with a branch you can push to. It provides the `tools/` and `appproject/` directories used in this guide and receives the generated ApplicationSets and values files in [3.18](#318-commit-and-push-applicationset-manifests-and-helm-values-configuration-files-to-git-repo). |

### Setting up client workstation
| Requirement | Notes |
|---|---|
|Installing `podman` |The tool is used for running and managing the `olm-utils-premium-v4` container. |
|Installing `git` |The tool is used for cloning the Git repos hosting Argo CD relevant assets.|
|Installing `jq` and `wget` |`jq` reads the olm-utils work directory in 3.10 and 3.14. `wget` downloads the cpd-cli in 3.1.3. `curl`, `tar`, `sudo` and `sha256sum` are also used and are normally already installed. |
|[Installing the IBM Software Hub command-line interface](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=workstation-installing-software-hub-cli)|Download Version 14.4.0.8 of the cpd-cli from the [IBM/cpd-cli](https://github.com/IBM/cpd-cli/releases) repository on GitHub.|
|[Installing the OpenShift client](https://www.ibm.com/docs/en/SSNFH6_5.4.x/hub/install/setup-client-oc-cli.html)|The IBM Software Hub command-line interface (cpd-cli) interacts with the OpenShift client (oc CLI) to issue commands to your OpenShift cluster.|
|[Downloading olm-utils-premium-v4 image](Mirror%20olm-utils-premium-v4%20image.md) | The `olm-utils-premium-v4` image is required for creating Argo CD Applications and ApplicationSets. An IBM Software Hub Premium entitlement is required to download this image.|
|[Installing Helm CLI](https://helm.sh/docs/intro/install/)|Install the Helm command-line interface to manage Helm charts.|
|[Argo CD CLI](https://argo-cd.readthedocs.io/en/stable/getting_started/#2-download-argo-cd-cli)|Required. It registers the repositories (3.6), verifies the AppProject (3.13) and syncs the Applications (3.19). It is downloaded and checksum-verified in [3.6](#36-argo-cd-repository-registration), so there is nothing to install beforehand.|
| Network access | The workstation can reach github.com (cpd-cli, Argo CD CLI and health-check files), your Git server, your Helm repo, the OpenShift API and the private registry. The cluster can reach the Git server, the Helm repo and the private registry. |

### Access & credentials

| Requirement | Notes |
|---|---|
| OpenShift `cluster-admin` user | An OpenShift user with the `cluster-admin` ClusterRole runs the installation (`oc` commands and `argocd login --core`). For Argo CD UI and CLI (`--sso`) access, the same user must also be a member of the OpenShift `cluster-admins` group, because Argo CD evaluates group membership, not ClusterRoleBindings. See [ArgoCD-RBAC-OCP-Groups.md](ArgoCD-RBAC-OCP-Groups.md). If you do not have such a user, create one by following [Create-Cluster-Admin-ArogCD-Deployment.md](Create-Cluster-Admin-ArogCD-Deployment.md), which uses the HTPasswd identity provider as an example. |
| `cluster-admin` for the Argo CD application controller | This deployment also grants `cluster-admin` to the Argo CD application controller service account in [3.8](#38-grant-argo-cd-access), because the cluster-scoped ApplicationSets create CRDs, ClusterRoles and ClusterRoleBindings. A separation-of-duties model with a narrower custom ClusterRole is possible, but it is not covered in this guide. |
| IBM entitlement key with IBM Software Hub Premium entitlement | Must be available for mirroring IBM Software Hub service images, including the `olm-utils-premium-v4` image. |
| Private registry credentials | Must be available for pulling images from the private image registry. |
| Access to the Git repo and the Helm repo | A user and a personal access token that can read both repos and push to both from the workstation. Argo CD needs read credentials for each private repo, which you add in [3.6](#36-argo-cd-repository-registration). Enter tokens at a prompt, never in a URL. |


### Governance & authorization
| Requirement | Notes |
|---|---|
| Create an AppProject object (e.g. `ibm-software-hub`) for the governance and authorization purpose. | The Argo CD `default` project places no restrictions on what can be deployed, from where, to which namespaces, or by whom. Refer to [ArgoCD-AppProject-Best-Practices.md](ArgoCD-AppProject-Best-Practices.md) for more details. You must add your Helm repo to the project's `sourceRepos` and check its `destinations` in [3.13](#313-apply-the-appproject). |

### Mirroring images
| Requirement | Notes |
|---|---|
|[Mirroring images to a private container registry](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=prufpcr-mirroring-images-private-container-registry)| A private container image registry must be available, reachable from the cluster, and pre-populated with all required IBM Software Hub component images|


### Cluster preparation
- [Changing required node settings](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=cluster-changing-required-node-settings)
- [Installing OpenShift GitOps](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops/1.20/html/installing_gitops/index). This guide uses the default Argo CD instance `openshift-gitops` in the `openshift-gitops` project (`PROJECT_ARGOCD`).
- [Scaling Argo CD](Scale-ArgoCD.md). Many Argo CD Applications sync at the same time when you deploy IBM Software Hub, which can cause the application controller pod to be OOMKilled. Increase its CPU and memory limits before you start the deployment.
- [Installing Red Hat certificate manager](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=cluster-installing-cert-manager-operator). 
- [Installing prerequisite software](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=cluster-installing-prerequisite-software)

---

## 3. Step-by-step deployment procedures

### 3.1 Set up workstation
#### 3.1.1 Install Podman, Git, jq and wget
```bash
yum install podman git jq wget -y
```

#### 3.1.2 Create the work directory for Argo CD deployment
```bash
mkdir -p /opt/ibm/argocd
export ARGOCD_DIR=/opt/ibm/argocd
```

#### 3.1.3 Installing the cpd-cli
**Note:** You may need to change the version according to the target version of your IBM Software Hub services deployment.
<br>
Download Version 14.4.0.8 of the cpd-cli from the IBM repository on GitHub in this example.
<br>

- 1. Download with wget
```bash
cd $ARGOCD_DIR
wget https://github.com/IBM/cpd-cli/releases/download/v14.4.0.8/cpd-cli-linux-EE-14.4.0.tgz
```

- 2. Extract the tar file
```bash
tar -xvf cpd-cli-linux-EE-14.4.0.tgz
```

- 3. Make the cpd-cli executable from any directory.
```bash
export PATH=$ARGOCD_DIR/cpd-cli-linux-EE-14.4.0-3615:$PATH
```

Validate with the following command
```bash
cpd-cli version
```

The output looks like below:
```
cpd-cli
	Version: 14.4.0
	Build Date: 2026-10-13T17:54:31
	Build Number: 3615
	SWH Release Version: 5.4.0
```

### 3.2 Creating an environment variables file

- 1. Create an environment variable file named `cpd_vars.sh` in  `$ARGOCD_DIR`

```bash
cd $ARGOCD_DIR
touch cpd_vars.sh && chmod 600 cpd_vars.sh
```

> ⚠️ **Security:** `cpd_vars.sh` holds credentials (the OpenShift token or password, the IBM entitlement key and the registry passwords). The `chmod 600` above makes it readable only by you, and it is done before you add any secrets. Never commit this file to Git or share it, and do not put credentials in the URLs in it (for example `https://user:token@host/...`).

You can follow this IBM Documentation [Setting up installation environment variables](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=information-setting-up-installation-environment-variables) for creating the environment variable file. The content looks like below.

```bash
# ------------------------------------------------------------------------------
# Cluster
# ------------------------------------------------------------------------------

export OCP_URL=<enter your Red Hat OpenShift Container Platform URL>
export OPENSHIFT_TYPE=<enter your deployment type>
export IMAGE_ARCH=<enter your cluster architecture>
export OCP_TOKEN=<enter your token>
export SERVER_ARGUMENTS="--server=${OCP_URL}"
export LOGIN_ARGUMENTS="--token=${OCP_TOKEN}"
# To log in with a username and password instead, use the following three lines in place of the OCP_TOKEN and LOGIN_ARGUMENTS lines above:
# export OCP_USERNAME=<enter your username>
# export OCP_PASSWORD=<enter your password>
# export LOGIN_ARGUMENTS="--username=${OCP_USERNAME} --password=${OCP_PASSWORD}"
export CPDM_OC_LOGIN="cpd-cli manage login-to-ocp ${SERVER_ARGUMENTS} ${LOGIN_ARGUMENTS}"
export OC_LOGIN="oc login ${OCP_URL} ${LOGIN_ARGUMENTS}"

# ------------------------------------------------------------------------------
# Projects
# ------------------------------------------------------------------------------

export PROJECT_LICENSE_SERVICE=ibm-licensing
export PROJECT_IBM_EVENTS=ibm-knative-events
export PROJECT_CPD_INST_OPERATORS=<enter your IBM Software Hub operator project>
export PROJECT_CPD_INST_OPERANDS=<enter your IBM Software Hub operand project>

# ------------------------------------------------------------------------------
# Storage
# ------------------------------------------------------------------------------

export STG_CLASS_BLOCK=ocs-storagecluster-ceph-rbd
export STG_CLASS_FILE=ocs-storagecluster-cephfs

# ------------------------------------------------------------------------------
# IBM Entitled Registry
# ------------------------------------------------------------------------------

export IBM_ENTITLEMENT_KEY=<enter your IBM entitlement API key>

# ------------------------------------------------------------------------------
# Private container registry
# ------------------------------------------------------------------------------
# Set the following variables if you mirror images to a private container registry.

export PRIVATE_REGISTRY_LOCATION=<enter the location of your private container registry>
export PRIVATE_REGISTRY_PUSH_USER=<enter the username of a user that can push to the registry>
export PRIVATE_REGISTRY_PUSH_PASSWORD=<enter the password of the user that can push to the registry>
export PRIVATE_REGISTRY_PULL_USER=<enter the username of a user that can pull from the registry>
export PRIVATE_REGISTRY_PULL_PASSWORD=<enter the password of the user that can pull from the registry>

# ------------------------------------------------------------------------------
# Image pull configuration
# ------------------------------------------------------------------------------

export IMAGE_PULL_SECRET=ibm-entitlement-key
export IMAGE_PULL_CREDENTIALS=$(echo -n "$PRIVATE_REGISTRY_PULL_USER:$PRIVATE_REGISTRY_PULL_PASSWORD" | base64 -w 0)
export IMAGE_PULL_PREFIX=${PRIVATE_REGISTRY_LOCATION}

# ------------------------------------------------------------------------------
# Components
# ------------------------------------------------------------------------------

export VERSION=5.4.0
export COMPONENTS=ibm-licensing,cpfs,cpd_platform,datastage_ent_plus,ws_pipelines
export PATCH_ID=8

# ------------------------------------------------------------------------------
# Argo CD settings
# ------------------------------------------------------------------------------

export OLM_UTILS_IMAGE=$PRIVATE_REGISTRY_LOCATION/cp/cpd/olm-utils-premium-v4:5.4.0
export PROJECT_ARGOCD=openshift-gitops
# Do not put credentials in these URLs
export HELM_REPO_URL=<enter the URL of Helm repo>
# export HELM_REPO_URL=https://raw.githubusercontent.com/jhwhenry/gitops-charts/main/softwarehub
# The URL must NOT end with .git
export ARGOCD_APPSET_CONFIG_GIT_REPO_URL=<enter the URL of the Git repo hosting the Argo CD applicationsets and configuration files>
# export ARGOCD_APPSET_CONFIG_GIT_REPO_URL=https://github.com/jhwhenry/gitops-tech-preview
# The Git branch hosting the Argo CD applicationsets and configuration files.
# For VERSION=5.4.0 and PATCH_ID=8 this is 5.4.0_Patch8, the branch checked out in 3.12.
export ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH=${VERSION}_Patch${PATCH_ID}
# The Argo CD AppProject for the governance and authorization
export ARGOCD_APPLICATION_PROJECT=<enter the name of your Argo CD AppProject name>
# export ARGOCD_APPLICATION_PROJECT=ibm-software-hub
# Use the directory that you created in 3.1.2
export ARGOCD_DIR=<enter the name of your Argo CD deployment work directory>
# export ARGOCD_DIR=/opt/ibm/argocd

```

- 2. Source the environment variable
```bash
source cpd_vars.sh
```

**Note:** Run `source $ARGOCD_DIR/cpd_vars.sh` again in every new terminal. The variables that this guide exports later (`WORK_DIR`, `CASES_DIR` and `HELM_CHARTS_DIR`) are not stored in `cpd_vars.sh`, so export them again (3.10 and 3.16.1) if you continue in a new terminal.

### 3.3 Start up olm-utils-premium-v4 container
```bash
cpd-cli manage restart-container
```

### 3.4 Log into the OCP cluster
```bash
${OC_LOGIN}
${CPDM_OC_LOGIN}
```

### 3.5 Configure Argo CD instance to incorporate custom health checks for IBM Software Hub
Clone the Argo CD health check relevant files for IBM Software Hub
```bash
cd $ARGOCD_DIR
git clone https://github.com/IBM/cpd-cli.git
```
Patch the Argo CD instance to apply all health checks defined in the `custom-health-checks.yaml` file.
```bash
cp -r cpd-cli/docs/argocd/* .
oc patch argocd openshift-gitops -n openshift-gitops --patch-file custom-health-checks.yaml --type=merge
```

### 3.6 Argo CD repository registration

1. Download & Set up Argo CD CLI
```bash
# Use the version that matches the Argo CD deployed by your OpenShift GitOps operator
export ARGOCD_CLI_VERSION=v3.6.1
export ARGOCD_CLI_URL=https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_CLI_VERSION}

(
  set -euo pipefail
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT
  cd "$TMP_DIR"

  curl -fsSL -o argocd-linux-amd64 ${ARGOCD_CLI_URL}/argocd-linux-amd64
  curl -fsSL -o cli_checksums.txt ${ARGOCD_CLI_URL}/cli_checksums.txt

  # Install only if the SHA-256 checksum of the download matches the published one
  EXPECTED=$(awk '$2=="argocd-linux-amd64" {print $1}' cli_checksums.txt)
  [ -n "$EXPECTED" ]
  echo "${EXPECTED}  argocd-linux-amd64" | sha256sum -c -
  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
)

argocd version --client
```
The command stops, and nothing is installed, if the checksum does not match.

2. Configure the Argo CD CLI to use your current OpenShift connection
```bash
oc project $PROJECT_ARGOCD
argocd login --core
```
**Note:**  DO NOT change oc project while using argocd cli. This will log argocd cli out.

> **Note:** `argocd login --core` uses your kubeconfig identity and bypasses Argo CD authentication and RBAC. Use it only for the installation by cluster administrators. For day-to-day operations, use `argocd login <server> --sso` so that the OpenShift group mappings in [ArgoCD-RBAC-OCP-Groups.md](ArgoCD-RBAC-OCP-Groups.md) apply.

3. Connect Argo CD to the Git repo
Before any ApplicationSet can sync, Argo CD must have credentials to
pull from the Git repository, if it is private.

Replace `<github-username>` with a user that can read the repository on your Git server. Leave out `--password`. The CLI then prompts for it, so the token does not appear in the shell history or the process list. Paste a personal access token for that user at the `Password:` prompt (the input is hidden on a terminal).

```bash
# Using the Argo CD CLI
argocd repo add $ARGOCD_APPSET_CONFIG_GIT_REPO_URL \
  --username <github-username>
```

If the Git repo is public, no credentials are needed.

```bash
argocd repo add $ARGOCD_APPSET_CONFIG_GIT_REPO_URL
```

4. Connect Argo CD to the Helm repo
The Applications pull their Helm charts from `$HELM_REPO_URL`, the Helm repo you push the charts to in [3.16](#316-prepare-helm-charts-and-push-them-to-the-helm-repo). If this repo is private, Argo CD must have credentials for it as well, otherwise the Applications fail with an authentication error.

`argocd repo add` requires `--name` for a Helm repo. For a private repo, pass `--username` and leave out `--password`. The CLI then prompts for the password, so the token does not appear in the shell history or the process list. Paste a personal access token that can read the Helm repo at the `Password:` prompt (the input is hidden on a terminal).

```bash
argocd repo add $HELM_REPO_URL --type helm --name swh-charts --username <username>
```

If the Helm repo is public, no credentials are needed.

```bash
argocd repo add $HELM_REPO_URL --type helm --name swh-charts
```

Verify that the repo is registered.

```bash
argocd repo list
```

### 3.7 Create namespaces
```bash
oc new-project $PROJECT_CPD_INST_OPERATORS
oc new-project $PROJECT_CPD_INST_OPERANDS
oc new-project $PROJECT_LICENSE_SERVICE
oc project $PROJECT_ARGOCD
```

### 3.8 Grant Argo CD access

Grant Argo CD access by binding admin role to `system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller` service account in below namespaces.

```bash
oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n $PROJECT_CPD_INST_OPERATORS

oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n $PROJECT_CPD_INST_OPERANDS

oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n $PROJECT_LICENSE_SERVICE

oc adm policy add-role-to-user admin \
  system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller \
  -n $PROJECT_ARGOCD
```

Grant Argo CD the cluster-admin access.

> ⚠️ **Security:** This is a deliberate, broad grant. The cluster-scoped ApplicationSets create resources that namespace `admin` access cannot create: CustomResourceDefinitions, ClusterRoles and ClusterRoleBindings. For example, the `ibm-licensing-cluster-scoped` chart renders 4 CRDs, 5 ClusterRoles and 5 ClusterRoleBindings. The `admin` bindings above cover the namespace-scoped resources only. If your security policy does not allow `cluster-admin`, a separation-of-duties model with a narrower custom ClusterRole is possible, but it is not covered in this guide.

```bash
oc adm policy add-cluster-role-to-user cluster-admin \
system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller
```

Argo CD needs this access for every sync and upgrade, so keep it while the deployment is managed by Argo CD. When you decommission the deployment, remove it.

```bash
oc adm policy remove-cluster-role-from-user cluster-admin \
system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller
```

### 3.9 Create an image pull secret

Create an image pull secret `ibm-entitlement-key` in the operator and instance namespace and licensing namespace. Make sure the credentials can pull images from your private registry.

Create a file named `dockerconfig.json` based on where your cluster pulls images from. The file contains your registry credentials, so it is created with owner-only permissions (`umask 077`) and deleted after the secrets are created:

```bash
(umask 077; cat <<EOF > dockerconfig.json
{
  "auths": {
    "${PRIVATE_REGISTRY_LOCATION}": {
      "auth": "${IMAGE_PULL_CREDENTIALS}"
    }
  }
}
EOF
)
```

Create the image pull secret in the operators project for the instance:

```bash
oc create secret docker-registry ${IMAGE_PULL_SECRET} \
--from-file ".dockerconfigjson=dockerconfig.json" \
--namespace=${PROJECT_CPD_INST_OPERATORS}
```

Create the image pull secret in the operands project for the instance:

```bash
oc create secret docker-registry ${IMAGE_PULL_SECRET} \
--from-file ".dockerconfigjson=dockerconfig.json" \
--namespace=${PROJECT_CPD_INST_OPERANDS}
```

Create the image pull secret in the licensing project:

```bash
oc create secret docker-registry ${IMAGE_PULL_SECRET} \
--from-file ".dockerconfigjson=dockerconfig.json" \
--namespace=${PROJECT_LICENSE_SERVICE}
```

Delete the `dockerconfig.json` file now that the secrets exist.

```bash
rm -f dockerconfig.json
```

> **Note:** The secret name `${IMAGE_PULL_SECRET}` must match the
> `global.imagePullSecret` value set in the ApplicationSet
> `valuesObject`.


### 3.10 Download the CASE packages
Download the CASE packages for the components.

```bash
cpd-cli manage case-download --components=$COMPONENTS \
--release=$VERSION --patch_id=$PATCH_ID
```

Validate the CASE packages downloaded to the cases folder successfully.

```bash
export WORK_DIR=$(podman inspect olm-utils-play-v4 | jq -r '.[0].Mounts' |jq -r '.[] | select(.Destination == "/tmp/work") | .Source')
ls -alrt $WORK_DIR/offline/${VERSION}/.ibm-pak/data/cases
```

### 3.11 Clone the `gitops-charts` Helm repo to your local workstation

The example below clones the `gitops-charts` repo. If you use a different Helm repo, clone that one instead. The directory you copy the charts into in 3.16 must be the one that `HELM_REPO_URL` serves.

```bash
cd $ARGOCD_DIR
git clone https://github.com/jhwhenry/gitops-charts.git
```

### 3.12 Clone the `gitops-tech-preview` git repo to your local workstation

This is the Git repo that you set in `ARGOCD_APPSET_CONFIG_GIT_REPO_URL`. The later steps expect its `tools/` and `appproject/` directories under `$ARGOCD_DIR/gitops-tech-preview`, so if you use your own copy, it must contain them and be cloned into that directory.

```bash
cd $ARGOCD_DIR
git clone https://github.com/jhwhenry/gitops-tech-preview.git
cd $ARGOCD_DIR/gitops-tech-preview
git checkout -b $ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH
git branch --show-current
```

The last command must print the value of `ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH` (`5.4.0_Patch8` in this example). 

### 3.13 Apply the AppProject

The `ibm-software-hub` AppProject defines source trust boundaries, allowed destinations,
resource access gates, and RBAC roles for all IBM Software Hub Argo CD Applications.
It must be applied **before** applying the ApplicationSets, as the
generated Applications reference this project by name (`argocd.project` in `install-options.yaml`). The name must match `ARGOCD_APPLICATION_PROJECT` in `cpd_vars.sh`.

> ⚠️ **Important:** `appproject/argocd-project.yaml` contains placeholders and default values. You **must** edit the file for your environment before you apply it. Otherwise, the Applications cannot sync, because Argo CD rejects any source repo or destination namespace that the project does not allow.

Edit `appproject/argocd-project.yaml` as follows. You can use the environment variables in `cpd_vars.sh` to get the values. Run `source $ARGOCD_DIR/cpd_vars.sh` first if this is a new terminal.

1. Update **both** the Git repo and the Helm repo in `spec.sourceRepos`. The file contains a placeholder for each of them, and you must replace both:
   - The Git repo that hosts the ApplicationSets and configuration files: use the value of `ARGOCD_APPSET_CONFIG_GIT_REPO_URL`.
   - The Helm repo that hosts the Helm charts: use the value of `HELM_REPO_URL`. The Applications pull their charts from this repo, and a Helm repo URL is matched literally, so the entry must be exactly the same as `HELM_REPO_URL`.

   ```bash
   echo $ARGOCD_APPSET_CONFIG_GIT_REPO_URL
   echo $HELM_REPO_URL
   ```

   ```yaml
     sourceRepos:
       - "<your ARGOCD_APPSET_CONFIG_GIT_REPO_URL>"
       - "<your HELM_REPO_URL>"
   ```

2. Change the namespaces of `cpd-operators`, `cpd-instance` and `ibm-licensing` in `spec.destinations` if the namespaces of your deployment are different. They must be exactly the same as the namespaces you created in [3.7](#37-create-namespaces) and use in `install-options.yaml`. Keep the `openshift-gitops` entry unless your Argo CD instance runs in a different namespace. Also keep the `default` and the empty-namespace (`""`) entries: the generated Applications use `default` (namespace-scoped charts) or no namespace (cluster-scoped charts) as their destination, and Argo CD rejects them if these entries are removed.

   | Namespace in the file | Replace with | Environment variable in `cpd_vars.sh` |
   |---|---|---|
   | `cpd-operators` | IBM Software Hub operator namespace | `PROJECT_CPD_INST_OPERATORS` |
   | `cpd-instance` | IBM Software Hub instance (operand) namespace | `PROJECT_CPD_INST_OPERANDS` |
   | `ibm-licensing` | IBM License Service namespace | `PROJECT_LICENSE_SERVICE` |
   | `openshift-gitops` | Argo CD namespace | `PROJECT_ARGOCD` |

   ```bash
   echo $PROJECT_CPD_INST_OPERATORS
   echo $PROJECT_CPD_INST_OPERANDS
   echo $PROJECT_LICENSE_SERVICE
   echo $PROJECT_ARGOCD
   ```

   ```yaml
     destinations:
       - name: in-cluster
         namespace: <your PROJECT_CPD_INST_OPERATORS>
         server: "https://kubernetes.default.svc"
       - name: in-cluster
         namespace: <your PROJECT_CPD_INST_OPERANDS>
         server: "https://kubernetes.default.svc"
       - name: in-cluster
         namespace: <your PROJECT_LICENSE_SERVICE>
         server: "https://kubernetes.default.svc"
       - name: in-cluster
         namespace: openshift-gitops
         server: "https://kubernetes.default.svc"
       - name: in-cluster
         namespace: default
         server: "https://kubernetes.default.svc"
       - name: in-cluster
         namespace: ""
         server: "https://kubernetes.default.svc"
   ```

Then apply the AppProject:

```bash
cd $ARGOCD_DIR/gitops-tech-preview
oc apply -f appproject/argocd-project.yaml
```

Verify the AppProject was created successfully:

```bash
oc get appproject ibm-software-hub -n openshift-gitops
argocd proj list
```

### 3.14 Create install-options.yaml
1. Go to the `ARGOCD_DIR` folder.
```bash
cd $ARGOCD_DIR
```

2. Ensure the following environment variables are set properly in the `cpd_vars.sh`.

```bash
echo $HELM_REPO_URL

echo $ARGOCD_APPSET_CONFIG_GIT_REPO_URL

echo $ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH

echo $ARGOCD_APPLICATION_PROJECT
```

3. Create an `install-options.yaml` file with your deployment configuration. Leverage the environment variable file named `cpd_vars.sh`.

**Note:** Remove `ibm-licensing` from $COMPONENTS; otherwise, the create-argo-appsets command will fail.

```bash

export COMPONENTS=$(
  printf '%s\n' "$COMPONENTS" |
  tr ',' '\n' |
  grep -v '^ibm-licensing$' |
  paste -sd ',' -
)

```

> ⚠️ **Important:**  Below is a template for creating the `install-options.yaml` file. Review the `install-options.yaml` file carefully and ensure the options are set correctly. Update the options if necessary. 

```bash
cat <<EOF > install-options.yaml

#------------------------------------------------------------------------------
# Section 1: Global Installation Options
#------------------------------------------------------------------------------
globalOptions:
  # License acceptance (REQUIRED)
  licenseAccept: true
  # CPD release version (REQUIRED)
  releaseVersion: ${VERSION}
  # Components to install (REQUIRED), Comma-separated string
  components: ${COMPONENTS}
  # Namespace configuration
  operatorNamespace: ${PROJECT_CPD_INST_OPERATORS}
  instanceNamespace: ${PROJECT_CPD_INST_OPERANDS}
  # Storage configuration (REQUIRED)
  fileStorageClass: ${STG_CLASS_FILE}
  blockStorageClass: ${STG_CLASS_BLOCK}
  # Image pull configuration
  imagePullPrefix: ${IMAGE_PULL_PREFIX}
  imagePullSecret: ${IMAGE_PULL_SECRET}
  # Installation control
  upgrade: false
  # Patch ID 
  patchId: ${PATCH_ID}

#------------------------------------------------------------------------------
# Section 2: Argo CD Configuration
#------------------------------------------------------------------------------
argocd:
  # Namespace where Argo CD operator is installed
  namespace: ${PROJECT_ARGOCD}
  # Argo CD AppProject name.
  project: ${ARGOCD_APPLICATION_PROJECT}
  # Git repository configuration
  git:
    # Helm chart repository URL
    chartRepo: ${HELM_REPO_URL}
    # Target Git repository URL (where applicationset and config files will be committed)
    targetRepoUrl: ${ARGOCD_APPSET_CONFIG_GIT_REPO_URL}
    # Target Git repository branch
    targetRepoBranch: ${ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH}

#------------------------------------------------------------------------------
# Section 3: Service-Specific Overrides
#------------------------------------------------------------------------------
# Component-level configuration overrides
# Use camelCase component names (e.g., cpdPlatform)
# Use for Helm deployments
serviceOptions:
  ccs:
    size: large
  datastageEntPlus:
    size: large
  wsPipelines:
    size: small
EOF

```

Copy the `install-options.yaml` to the `cpd-cli-workspace/olm-utils-workspace/work` directory.

```bash
export WORK_DIR=$(podman inspect olm-utils-play-v4 | jq -r '.[0].Mounts' |jq -r '.[] | select(.Destination == "/tmp/work") | .Source')

cp install-options.yaml $WORK_DIR/install-options.yaml

chmod 644 ${WORK_DIR}/install-options.yaml
```

### 3.15 Run create-argo-appsets command to create Argo CD applicationsets
```bash
cpd-cli manage create-argo-appsets \
    --install_option_file=${WORK_DIR}/install-options.yaml \
    --log_level=debug
```

**Note:** The `--install_option_file` flag requires your local file path (e.g., `/path/to/cpd-cli-workspace/olm-utils-workspace/work/install-options.yaml`), not the container's internal path (`/tmp/work/install-options.yaml`).

The above command will perform the following steps:

- Validate Configuration: Verify all required fields and component dependencies

- Generate Argo CD Resources: Create ApplicationSet manifests, Helm values configuration files and generate Helm charts


**Generated Output:**

The command generates the following directory structure in `cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/<release version>` (`$WORK_DIR/ArgoCD/${VERSION}`):

```text
[root@bastion-1 ArgoCD]# pwd
/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD
[root@bastion-1 ArgoCD]# tree .
.
└── 5.4.0
    ├── appsets
    │   ├── applicationsets
    │   │   ├── cluster-scoped-appset.yaml
    │   │   └── namespace-scoped-appset.yaml
    │   ├── README.md
    │   └── values-config
    │       ├── apps-config
    │       │   ├── ccs-config.yaml
    │       │   ├── cpd-platform-config.yaml
    │       │   ├── datastage-ent-plus-config.yaml
    │       │   ├── ibm-common-service-operator-config.yaml
    │       │   ├── ibm-iam-operator-config.yaml
    │       │   ├── ibm-pg-operator-config.yaml
    │       │   ├── ibm-usage-metering-config.yaml
    │       │   ├── opencontent-opensearch-config.yaml
    │       │   ├── platform-config-config.yaml
    │       │   ├── postgresql-config.yaml
    │       │   ├── ws-pipelines-config.yaml
    │       │   └── zen-config.yaml
    │       └── global-values-config.yaml
    └── charts
        ├── ccs-13.0.8+20261013.142720.198.tgz
        ├── ccs-cluster-scoped-13.0.8+20261013.142720.198.tgz
        ├── cpd-platform-5.10.8+20260929.105344.9.tgz
        ├── cpd-platform-cluster-scoped-5.10.8+20260929.105344.9.tgz
        ├── datastage-ent-plus-12.0.8+20260927.202412.29.tgz
        ├── datastage-ent-plus-cluster-scoped-12.0.8+20260927.202412.29.tgz
        ├── ibm-common-service-operator-4.19.3+20260915.101245.0.tgz
        ├── ......
```
A README document, such as `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/appsets/README.md`, will also be generated.

> ⚠️ **Important:**  Review the generated applicationSet manifests and Helm values configuration files before moving to the next step.

- Review the `cluster-scoped-appset.yaml` and `namespace-scoped-appset.yaml` in the `ArgoCD/5.4.0/appsets/applicationsets` folder.
- Review the Helm **global** values configuration file `global-values-config.yaml` in the `ArgoCD/5.4.0/appsets/values-config` folder.
Example of `global-values-config.yaml`:

```yaml
global:
  licenseAccept: true
  crAdoption: false
  releaseVersion: 5.4.0
  components:
    - postgresql
    - cpfs
    - datastage_ent_plus
    - zen
    - ws_pipelines
    - ibm_usage_metering
    - cpd_platform
    - opencontent_opensearch
    - ibm_pg_operator
    - ccs
    - platform-config

  # namespaces
  operatorNamespace: cpd-operators
  instanceNamespace: cpd-instance
  tetheredNamespaces: []

  # storage setting
  blockStorageClass: ocs-storagecluster-ceph-rbd
  fileStorageClass: ocs-storagecluster-cephfs

  # image setting
  imagePullPrefix: icr.io
  imagePullSecret: ibm-entitlement-key
  installConfigImagePullPrefix: cp.icr.io
  installConfigImageName: cp/cpd/olm-utils-premium-v4
  installConfigImageDigest: sha256:b5ccfeb648bd40e3b8a911319c4206007e98613aa599d81136da2c165c3d0419
  # pre-computed release_components_meta for olm-utils-cm ConfigMap template
  cmReleaseCompsMeta: ......
  # patch metadata
  cmPatchMetadata: ......
```

- Review the Helm values configuration files of **each service or component** in the `ArgoCD/5.4.0/appsets/values-config/apps-config` folder.
Example of `datastage-ent-plus-config.yaml`:
```yaml
# Service specific Configuration
# Combined cluster-scoped and namespace-scoped configuration

componentID: datastage-ent-plus

# Cluster-scoped chart configuration
clusterScoped:
  appName: datastage-ent-plus-cluster
  chart: datastage-ent-plus-cluster-scoped
  version: 12.0.8+20260927.202412.29

# Namespace-scoped chart configuration
namespaceScoped:
  appName: datastage-ent-plus
  chart: datastage-ent-plus
  version: 12.0.8+20260927.202412.29
  values: |
    datastageEntPlus:
      size: large
```

### 3.16 Prepare Helm charts and push them to the Helm repo
#### 3.16.1 Specify the Helm charts directory
Specify the target directory which will store the Helm charts. It's recommended using the absolute path of the `gitops-charts/softwarehub` directory created by the git clone command in the 3.11 step.
```bash
export HELM_CHARTS_DIR=$ARGOCD_DIR/gitops-charts/softwarehub
```

#### 3.16.2 Move the generated Helm charts to Helm charts directory
Move the Helm charts generated in the step 3.15 to Helm charts directory.
```bash
cp -r $WORK_DIR/ArgoCD/${VERSION}/charts/* $HELM_CHARTS_DIR
```

#### 3.16.3 Download the ibm-licensing Helm charts
The `ibm-licensing` CASE package does not contain the Helm charts. Download the `ibm-licensing` and `ibm-licensing-cluster-scoped` charts from the public IBM charts repo (`https://github.com/IBM/charts/tree/master/repo/ibm-helm`) into `$HELM_CHARTS_DIR` with the `download_licensing_charts.sh` tool. 

1. Get the `ibm-licensing` version from the `ibm-licensing` CASE file that [3.10](#310-download-the-case-packages) downloaded to `$CASES_DIR`. The file is named `ibm-licensing-<version>.tgz`, and the version is read from its name.
```bash
export CASES_DIR=${CASES_DIR:-$WORK_DIR/offline/${VERSION}/.ibm-pak/data/cases}
export LICENSING_VERSION=$(ls $CASES_DIR/ibm-licensing/*/ibm-licensing-[0-9]*.tgz 2>/dev/null \
  | sed -E 's#.*/ibm-licensing-(.*)\.tgz#\1#' | sort -V | tail -1)

echo "LICENSING_VERSION=${LICENSING_VERSION}"
```
The output is the version, for example `LICENSING_VERSION=4.2.25`. If it is empty, the `ibm-licensing` CASE file is missing. Check that `ibm-licensing` is in `$COMPONENTS` and re-run [3.10](#310-download-the-case-packages). If several versions are present, the highest one is used.

2. Download both charts for that version. The tool looks up the full file names, which carry a build suffix, in the repo index. It downloads nothing unless both charts exist for the version.

```bash
cd $ARGOCD_DIR/gitops-tech-preview
chmod +x ./tools/download_licensing_charts.sh

./tools/download_licensing_charts.sh -d $HELM_CHARTS_DIR $LICENSING_VERSION
```
The output looks like below.
```text
[23:26:45] Fetching https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm/index.yaml
[23:26:46] Downloading ibm-licensing-4.2.25+20260916.194642.0.tgz
[23:26:46] Saved /opt/ibm/argocd/gitops-charts/softwarehub/ibm-licensing-4.2.25+20260916.194642.0.tgz
[23:26:46] Downloading ibm-licensing-cluster-scoped-4.2.25+20260916.194642.0.tgz
[23:26:47] Saved /opt/ibm/argocd/gitops-charts/softwarehub/ibm-licensing-cluster-scoped-4.2.25+20260916.194642.0.tgz
[23:26:47] Done. Downloaded 2 charts to /opt/ibm/argocd/gitops-charts/softwarehub
```

3. Check that both files are in `$HELM_CHARTS_DIR`.
```bash
ls $HELM_CHARTS_DIR | grep -i licensing
```

**Note:**
- The workstation needs outbound HTTPS access to `raw.githubusercontent.com`. If it does not have it, run the tool on a connected machine and copy the two `.tgz` files to `$HELM_CHARTS_DIR`.
- Run `./tools/download_licensing_charts.sh -l` to list the versions available in the public repo.

#### 3.16.4 Push Helm charts to the Helm repo
1. Generate index.yaml
Make sure the `HELM_REPO_URL` set properly in the environment variable file `cpd_vars.sh`.

```bash
echo $HELM_REPO_URL
```

The `HELM_REPO_URL` looks like "https://raw.github.com/jhwhenry/gitops-charts/main/softwarehub".

Create the index.yaml for the Helm repo.

**Note:**
- `--url` must be the raw-file base URL for your Git server.
- Ensure `+` is percent-encoded `(%2B)` in all urls entries after generation

> ⚠️ **Important:** For incremental updates, always use `--merge` to preserve existing entries
```bash
helm repo index $HELM_CHARTS_DIR \
--url $HELM_REPO_URL  \
--merge $HELM_CHARTS_DIR/index.yaml
```

2. Commit and push Helm charts to the Helm repo

For example:

```bash
cd $ARGOCD_DIR/gitops-charts
git add softwarehub/
git commit -m "Add IBM Software Hub 5.4.0 Patch 8 charts"
git push origin main
```

### 3.17 Generate the ibm-licensing Helm values configuration file

The `create-argo-appsets` command does not generate a Helm values configuration file for the IBM Licensing service. Use the `generate_licensing_config.sh` tool to create `ibm-licensing-config.yaml`, so that the cluster-scoped and namespace-scoped ApplicationSets also create the `ibm-licensing-cluster` and `ibm-licensing` Applications.

The tool takes three required parameters:

| Parameter | Value | Where it comes from |
|---|---|---|
| `CHART_VERSION` | Version of the `ibm-licensing` and `ibm-licensing-cluster-scoped` charts | The charts downloaded in [3.16.3](#3163-download-the-ibm-licensing-helm-charts) and pushed to the Helm repo in [3.16.4](#3164-push-helm-charts-to-the-helm-repo) (`$HELM_CHARTS_DIR`) |
| `INSTANCE_NS` | Instance (operand) namespace that License Service also watches | `PROJECT_CPD_INST_OPERANDS` from `cpd_vars.sh` in [3.2](#32-creating-an-environment-variables-file), the same value used as `instanceNamespace` in `install-options.yaml` in [3.14](#314-create-install-optionsyaml) |
| `HELM_REPO_URL` | Helm repo the licensing Applications pull their charts from | `HELM_REPO_URL` from `cpd_vars.sh` in [3.2](#32-creating-an-environment-variables-file), the repo that `index.yaml` was created for in [3.16.4](#3164-push-helm-charts-to-the-helm-repo) |

1. Get the chart version from the charts downloaded in [3.16.3](#3163-download-the-ibm-licensing-helm-charts). The `ibm-licensing` and `ibm-licensing-cluster-scoped` charts are released with the same version.
```bash
# Skip this export if HELM_CHARTS_DIR is still set from 3.16.1 in this terminal
export HELM_CHARTS_DIR=$ARGOCD_DIR/gitops-charts/softwarehub
export LICENSING_CHART_VERSION=$(ls $HELM_CHARTS_DIR/ibm-licensing-[0-9]*.tgz \
  | sed -E 's#.*/ibm-licensing-(.*)\.tgz#\1#' | sort -V | tail -1)

echo $LICENSING_CHART_VERSION
```
Make sure the version matches the one in the `ibm-licensing-cluster-scoped-*.tgz` chart.
```bash
ls $HELM_CHARTS_DIR/ibm-licensing-cluster-scoped-${LICENSING_CHART_VERSION}.tgz
```

2. Verify the licensing charts are available in your Helm repo. The tool does not contact the Helm repo, so check here before generating the file. Add the repo to the Helm CLI on the workstation (the name `swh-charts` is just a local alias).

If it's a private Helm repo which requires authentication, run below command.
```bash
read -rs HELM_REPO_TOKEN
echo "$HELM_REPO_TOKEN" | helm repo add swh-charts "$HELM_REPO_URL" \
  --username <github-username> --password-stdin
unset HELM_REPO_TOKEN
```

If it's a public Helm repo which doesn't require authentication, run below command.

```bash
helm repo add swh-charts ${HELM_REPO_URL}
helm repo update swh-charts
```


Search the repo for the licensing charts.
```bash
helm search repo licensing
```
The output looks like below. Both charts must be listed.
```text
NAME                                   	CHART VERSION           	APP VERSION	DESCRIPTION
swh-charts/ibm-licensing               	4.2.25+20260916.194642.0	           	...
swh-charts/ibm-licensing-cluster-scoped	4.2.25+20260916.194642.0	           	...
```
Confirm that `${LICENSING_CHART_VERSION}` is available for both charts. Each command must list one row. `helm search repo` exits with 0 even when nothing matches, so check the output: `No results found` means the chart or version is missing, and you need to push it as described in [3.16.4](#3164-push-helm-charts-to-the-helm-repo) before continuing.
```bash
helm search repo swh-charts/ibm-licensing --version ${LICENSING_CHART_VERSION}
helm search repo swh-charts/ibm-licensing-cluster-scoped --version ${LICENSING_CHART_VERSION}
```

3. Run the tool from the `gitops-tech-preview` repo. The tool writes `${VERSION}/appsets/values-config/apps-config/ibm-licensing-config.yaml` in the repo, uses `PROJECT_LICENSE_SERVICE` (`ibm-licensing`) as the License Service namespace, and sets `repoURL` to your Helm repo for both Applications.
```bash
cd $ARGOCD_DIR/gitops-tech-preview
mkdir -p ${VERSION}/appsets/values-config/apps-config
chmod +x ./tools/generate_licensing_config.sh

RELEASE=${VERSION} LICENSING_NS=${PROJECT_LICENSE_SERVICE} \
./tools/generate_licensing_config.sh ${LICENSING_CHART_VERSION} ${PROJECT_CPD_INST_OPERANDS} ${HELM_REPO_URL}
```

4. Review the generated file.
```bash
cat ${VERSION}/appsets/values-config/apps-config/ibm-licensing-config.yaml
```
The output looks like below.
```yaml
componentID: ibm-licensing

clusterScoped:
  appName: ibm-licensing-cluster
  repoURL: "https://raw.github.com/jhwhenry/gitops-charts/main/softwarehub"
  chart: ibm-licensing-cluster-scoped
  version: 4.2.25+20260916.194642.0

namespaceScoped:
  appName: ibm-licensing
  repoURL: "https://raw.github.com/jhwhenry/gitops-charts/main/softwarehub"
  chart: ibm-licensing
  version: 4.2.25+20260916.194642.0
  values: |
    ibmLicensing:
      namespace: ibm-licensing
      watchNamespace: ibm-licensing,cpd-instance
```

**Note:**
- The generated `repoURL` makes Argo CD pull the licensing charts from your own Helm repo (`$HELM_REPO_URL`) instead of the public IBM Helm repo, which is the default when `repoURL` is not set. The charts must therefore be pushed there first, as in [3.16.4](#3164-push-helm-charts-to-the-helm-repo).
- The tool does not contact the Helm repo. It only writes the file, so it cannot tell whether the chart versions exist there. Step 1 confirms the `.tgz` files are in `$HELM_CHARTS_DIR`, and step 2 confirms the Helm repo serves them.
- The `ibm-licensing` namespace and the `${IMAGE_PULL_SECRET}` pull secret in it were created in [3.7](#37-create-namespaces) and [3.9](#39-create-an-image-pull-secret).
- Step [3.18](#318-commit-and-push-applicationset-manifests-and-helm-values-configuration-files-to-git-repo) copies the generated `${VERSION}` folder into the same repo. The copy merges into the existing folder, so `ibm-licensing-config.yaml` is kept unless the generated files already contain a file with the same name.

### 3.18 Commit and push applicationset manifests and helm values configuration files to Git repo

Navigate to the folder of the cloned Git repository.

```bash
cd $ARGOCD_DIR/gitops-tech-preview
```

Copy or move the generated files to your repository.
```bash
mkdir -p ${VERSION}
cp -r $WORK_DIR/ArgoCD/${VERSION}/appsets ${VERSION}/
```

Add the files to Git. For example:
```bash
git add ${VERSION}
```

Commit the changes.
```bash
git commit -m "Add SWH ${VERSION} Patch ${PATCH_ID} Argo CD ApplicationSets and configuration files"
```

Push to remote repository
```bash
git push origin ${ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH}
```

### 3.19 Apply ApplicationSets
- 1) Apply the **cluster-scoped** ApplicationSet manifests to your OpenShift cluster, then confirm its Applications have been generated
```bash
oc apply -f $WORK_DIR/ArgoCD/${VERSION}/appsets/applicationsets/cluster-scoped-appset.yaml

oc get applications -n ${PROJECT_ARGOCD} -l resource-scope=cluster-scoped
```

- 2) Auto sync is disabled, so the generated Applications stay `OutOfSync` until you sync them manually. Sync the cluster-scoped Applications and wait until they are synced and healthy (for example `argocd app sync <app> [-l resource-scope=cluster-scoped]` or from the Argo CD UI)

- 3) Important: Wait for **cluster-scoped** applications to be fully deployed before applying **namespace-scoped** ApplicationSet to ensure proper resource dependencies.

- 4) Once the cluster-scoped Applications are healthy, apply the **namespace-scoped** ApplicationSet, then confirm its Applications have been generated:

```bash
oc apply -f $WORK_DIR/ArgoCD/${VERSION}/appsets/applicationsets/namespace-scoped-appset.yaml

oc get applications -n ${PROJECT_ARGOCD} -l resource-scope=namespace-scoped
```

- 5) Sync the **namespace-scoped** Applications and wait until they are synced and healthy (for example `argocd app sync <app>` or from the Argo CD UI).
- 6) (Optional) Enable auto sync. By default the Applications are synced manually. To have Argo CD sync them automatically when the Git or Helm content changes, add an `automated` block to the `syncPolicy` of both ApplicationSets. Do this only after the Applications are synced and healthy (steps 1 to 5), so that the cluster-scoped Applications are deployed before the namespace-scoped ones.

  Use `oc patch` to add `automated` to `spec.template.spec.syncPolicy` of the live ApplicationSets. The other `syncPolicy` settings (`syncOptions` and `retry`) are kept. Patch the cluster-scoped ApplicationSet first:

  ```bash
  oc patch applicationset cpd-instance-cluster-scoped -n ${PROJECT_ARGOCD} --type=merge \
    -p '{"spec":{"template":{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}}}'

  oc patch applicationset cpd-instance-namespace-scoped -n ${PROJECT_ARGOCD} --type=merge \
    -p '{"spec":{"template":{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}}}'
  ```

  The patch sets `prune: false` (no automatic deletions) and `selfHeal: true` (manual changes on the cluster are reverted).

  Verify that the Applications now have auto sync enabled:

  ```bash
  oc get applications -n ${PROJECT_ARGOCD} -o custom-columns='NAME:.metadata.name,AUTOSYNC:.spec.syncPolicy.automated'
  ```

  **Notes:**
  - Keep `prune: false`. The cluster-scoped charts contain CustomResourceDefinitions, and deleting one deletes all of its custom resources.
  - With `selfHeal: true`, Argo CD reverts manual changes made directly on the cluster. Set it to `false` if administrators or operators need to change these resources by hand, or if an operator keeps modifying a resource that Argo CD manages and the two conflict.
  - Auto sync applies cluster-wide resources (CRDs, ClusterRoles, ClusterRoleBindings and webhook configurations) without a manual step, so protect the Git and Helm repos and review changes before merging them. See the security note in `appproject/argocd-project.yaml`.
  - The patch changes the live ApplicationSets only. If you apply `cluster-scoped-appset.yaml` or `namespace-scoped-appset.yaml` again, auto sync is switched off. Run the `oc patch` commands again after that. To make the change permanent, add the same `automated` block under `spec.template.spec.syncPolicy` in the two files and commit them to the Git repo.


## 4. Monitor ApplicationSet Generation

Monitor the ApplicationSets and the Applications they generate:

### 4.1 Check ApplicationSets status
```bash
oc get applicationsets -n openshift-gitops
```

### 4.2 Check generated Applications
```bash
oc get applications -n openshift-gitops
```

### 4.3 Watch Applications in real-time
```bash
watch oc get applications -n openshift-gitops
```
After applying the namespaced applications, access OpenShift web console and open the Argo CD web page by clicking the `Cluster Argo CD` icon.

It will take some time before all apps complete syncing (depending on the number of service components).  You can monitor the apps' status using the Argo CD application dashboard. 

Check and make sure all apps are synced without error.  Auto sync is disabled, so you must sync each app manually.

You can also monitor and sync apps using the argocd cli as another option.
```bash
argocd app list
argocd app sync <app-name>
```
