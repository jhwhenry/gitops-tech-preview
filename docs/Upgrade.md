# Argo CD Based Upgrade of IBM Software Hub services

## 1. Introduction

This document describes, step by step, how to upgrade IBM Software Hub services by using Argo CD.
We will use the upgrade of DataStage and Orchestration Pipelines from 5.4.0 patch 8 to 5.4.0 patch 9 as an example.

**Note:** Argo CD based upgrade requires IBM Software Hub Premium entitlement. 

**Assumption:** The existing environment 5.4.0 patch 8 was deployed following the [Argo CD framework](https://github.com/jhwhenry/gitops-tech-preview).

## 2. Pre-requisites

### Access & credentials

| Requirement | Notes |
|---|---|
| OpenShift `cluster-admin` user | An OpenShift user with the `cluster-admin` ClusterRole runs the installation (`oc` commands and `argocd login --core`). For Argo CD UI and CLI (`--sso`) access, the same user must also be a member of the OpenShift `cluster-admins` group, because Argo CD evaluates group membership, not ClusterRoleBindings. See [ArgoCD-RBAC-OCP-Groups.md](ArgoCD-RBAC-OCP-Groups.md). If you do not have such a user, create one by following [Create-Cluster-Admin-ArogCD-Deployment.md](Create-Cluster-Admin-ArogCD-Deployment.md), which uses the HTPasswd identity provider as an example. |
| IBM entitlement key with IBM Software Hub Premium entitlement | Must be available for mirroring IBM Software Hub service images, including the `olm-utils-premium-v4` image. |
| Private registry credentials | Must be available for pulling images from the private image registry. |
| Access to the Git repo and the Helm repo | A user and a personal access token that can read both repos and push to both from the workstation. |

### Mirroring images
| Requirement | Notes |
|---|---|
|[Mirroring images to a private container registry](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=prufpcr-mirroring-images-private-container-registry)| A private container image registry must be available, reachable from the cluster, and pre-populated with all required IBM Software Hub component images|

### Updating client workstation
| Requirement | Notes |
|---|---|
|[Updating the IBM Software Hub command-line interface](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=workstations-updating-software-hub-cli)|Download Version 14.4.0.8 of the cpd-cli from the [IBM/cpd-cli](https://github.com/IBM/cpd-cli/releases) repository on GitHub.|
|[Updating the olm-utils-premium-v4 image](Mirror%20olm-utils-premium-v4%20image.md)| The `olm-utils-premium-v4` image is required for creating Argo CD Applications and ApplicationSets. Ensure the correct version of the image is used.|

### Cluster preparation
- [Upgrading prerequisite software](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=cluster-upgrading-prerequisite-software)

---

## 3. Step-by-step upgrade procedures

### 3.1 Updating client workstation
#### 3.1.1 Updating the cpd-cli
**Note:** You may need to change the version according to the target version of your IBM Software Hub services deployment.
<br>
Download Version 14.4.0.8 of the cpd-cli from the IBM repository on GitHub in this example.
<br>

- 1. Download with wget
```bash
mkdir -p /opt/ibm/argocd
export ARGOCD_DIR=/opt/ibm/argocd
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
```text
cpd-cli
	Version: 14.4.0
	Build Date: 2026-10-13T17:54:31
	Build Number: 3615
	SWH Release Version: 5.4.0
```

### 3.2 Updating your environment variables script

1. Update the environment variable file `cpd_vars.sh` used by your previous Argo CD deployment.

You can follow this IBM Documentation [Updating your environment variables script](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=information-updating-your-environment-variables-script) for updating the environment variable file.

- Open your existing environment variable shell script in a text editor.
- Locate the `VERSION` entry and specify the version of IBM Software Hub that you want to upgrade to. For example:

```bash
export VERSION=5.4.0
```

- Set or update the `PATCH_ID` environment variable based on the patch that you want to install. For example:

```bash
export PATCH_ID=9
```

- Ensure the Argo CD settings section is set properly in the `cpd_vars.sh`.

```bash
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
# For VERSION=5.4.0 and PATCH_ID=9 this is 5.4.0_Patch9, the branch created in 3.7.
export ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH=${VERSION}_Patch${PATCH_ID}
# The Argo CD AppProject for the governance and authorization
export ARGOCD_APPLICATION_PROJECT=<enter the name of your Argo CD AppProject name>
# export ARGOCD_APPLICATION_PROJECT=ibm-software-hub
# Use the directory that you created in 3.1.1
export ARGOCD_DIR=<enter the name of your Argo CD deployment work directory>
# export ARGOCD_DIR=/opt/ibm/argocd
```

2. Source the environment variable
```bash
source cpd_vars.sh
```

### 3.3 Restart the olm-utils-premium-v4 container
Run the following command to ensure the cpd-cli manage plug-in has the correct version of the `olm-utils-premium-v4` image.

```bash
cpd-cli manage restart-container
```

### 3.4 Log into the OCP cluster

```bash
${OC_LOGIN}
${CPDM_OC_LOGIN}
```

### 3.5 Download the CASE packages
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

### 3.6 Clone the `gitops-charts` Helm repo to your local workstation

The example below clones the `gitops-charts` repo. If you use a different Helm repo, clone that one instead. The directory you copy the charts into in 3.10 must be the one that `HELM_REPO_URL` serves.

```bash
cd $ARGOCD_DIR
git clone https://github.com/jhwhenry/gitops-charts.git
```

### 3.7 Clone the `gitops-tech-preview` git repo to your local workstation

This is the Git repo that you set in `ARGOCD_APPSET_CONFIG_GIT_REPO_URL`. The later steps expect its `tools/` directory under `$ARGOCD_DIR/gitops-tech-preview`, so if you use your own copy, it must contain this directory and be cloned into that directory.

```bash
cd $ARGOCD_DIR
git clone https://github.com/jhwhenry/gitops-tech-preview.git
cd $ARGOCD_DIR/gitops-tech-preview
```

Create a new branch for hosting the new ApplicationSet yaml and Helm value configuration files.
```bash
git checkout -b $ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH
git branch --show-current
```

The last command must print the value of `ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH` (`5.4.0_Patch9` in this example). [3.12](#312-commit-and-push-applicationset-manifests-and-helm-values-configuration-files-to-git-repo) pushes this branch.

### 3.8 Create install-options.yaml
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
  upgrade: true
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

### 3.9 Run create-argo-appsets command to create Argo CD applicationsets
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
  ......

# Namespace-scoped chart configuration
namespaceScoped:
  appName: datastage-ent-plus
  chart: datastage-ent-plus
  ......
  values: |
    datastageEntPlus:
      size: large
                          
```

### 3.10 Prepare Helm charts and push them to the Helm repo
#### 3.10.1 Specify the Helm charts directory
Specify the target directory which will store the Helm charts. It's recommended using the absolute path of the `gitops-charts/softwarehub` directory created by the git clone command in the 3.6 step.
```bash
export HELM_CHARTS_DIR=$ARGOCD_DIR/gitops-charts/softwarehub
```

#### 3.10.2 Move the generated Helm charts to Helm charts directory
Move the Helm charts generated in the step 3.9 to Helm charts directory.
```bash
cp -r $WORK_DIR/ArgoCD/${VERSION}/charts/* $HELM_CHARTS_DIR
```

#### 3.10.3 Download the ibm-licensing Helm charts
The `ibm-licensing` CASE package does not contain the Helm charts. Download the `ibm-licensing` and `ibm-licensing-cluster-scoped` charts from the public IBM charts repo (`https://github.com/IBM/charts/tree/master/repo/ibm-helm`) into `$HELM_CHARTS_DIR` with the `download_licensing_charts.sh` tool. 

1. Get the `ibm-licensing` version from the `ibm-licensing` CASE file that [3.5](#35-download-the-case-packages) downloaded to `$CASES_DIR`. The file is named `ibm-licensing-<version>.tgz`, and the version is read from its name.
```bash
export CASES_DIR=${CASES_DIR:-$WORK_DIR/offline/${VERSION}/.ibm-pak/data/cases}
export LICENSING_VERSION=$(ls $CASES_DIR/ibm-licensing/*/ibm-licensing-[0-9]*.tgz 2>/dev/null \
  | sed -E 's#.*/ibm-licensing-(.*)\.tgz#\1#' | sort -V | tail -1)

echo "LICENSING_VERSION=${LICENSING_VERSION}"
```
The output is the version, for example `LICENSING_VERSION=4.2.26`. If it is empty, the `ibm-licensing` CASE file is missing. Check that `ibm-licensing` is in `$COMPONENTS` and re-run [3.5](#35-download-the-case-packages). If several versions are present, the highest one is used.

2. Download both charts for that version. The tool looks up the full file names, which carry a build suffix, in the repo index. It downloads nothing unless both charts exist for the version.

```bash
cd $ARGOCD_DIR/gitops-tech-preview
chmod +x ./tools/download_licensing_charts.sh

./tools/download_licensing_charts.sh -d $HELM_CHARTS_DIR $LICENSING_VERSION
```
The output looks like below.
```text
[23:26:45] Fetching https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm/index.yaml
[23:26:46] Downloading ibm-licensing-4.2.26+20261015.180257.0.tgz
[23:26:46] Saved /opt/ibm/argocd/gitops-charts/softwarehub/ibm-licensing-4.2.26+20261015.180257.0.tgz
[23:26:46] Downloading ibm-licensing-cluster-scoped-4.2.26+20261015.180257.0.tgz
[23:26:47] Saved /opt/ibm/argocd/gitops-charts/softwarehub/ibm-licensing-cluster-scoped-4.2.26+20261015.180257.0.tgz
[23:26:47] Done. Downloaded 2 charts to /opt/ibm/argocd/gitops-charts/softwarehub
```

3. Check that both files are in `$HELM_CHARTS_DIR`.
```bash
ls $HELM_CHARTS_DIR | grep -i licensing
```

**Note:**
- The workstation needs outbound HTTPS access to `raw.githubusercontent.com`. If it does not have it, run the tool on a connected machine and copy the two `.tgz` files to `$HELM_CHARTS_DIR`.
- Run `./tools/download_licensing_charts.sh -l` to list the versions available in the public repo.

#### 3.10.4 Push Helm charts to the Helm repo
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
git commit -m "Add IBM Software Hub 5.4.0 Patch 9 charts"
git push origin main
```

### 3.11 Generate the ibm-licensing Helm values configuration file

The `create-argo-appsets` command does not generate a Helm values configuration file for the IBM Licensing service. Use the `generate_licensing_config.sh` tool to create `ibm-licensing-config.yaml`, so that the cluster-scoped and namespace-scoped ApplicationSets also create the `ibm-licensing-cluster` and `ibm-licensing` Applications.

The tool takes three required parameters:

| Parameter | Value | Where it comes from |
|---|---|---|
| `CHART_VERSION` | Version of the `ibm-licensing` and `ibm-licensing-cluster-scoped` charts | The charts downloaded in [3.10.3](#3103-download-the-ibm-licensing-helm-charts) and pushed to the Helm repo in [3.10.4](#3104-push-helm-charts-to-the-helm-repo) (`$HELM_CHARTS_DIR`) |
| `INSTANCE_NS` | Instance (operand) namespace that License Service also watches | `PROJECT_CPD_INST_OPERANDS` from `cpd_vars.sh` in [3.2](#32-updating-your-environment-variables-script), the same value used as `instanceNamespace` in `install-options.yaml` in [3.8](#38-create-install-optionsyaml) |
| `HELM_REPO_URL` | Helm repo the licensing Applications pull their charts from | `HELM_REPO_URL` from `cpd_vars.sh` in [3.2](#32-updating-your-environment-variables-script), the repo that `index.yaml` was created for in [3.10.4](#3104-push-helm-charts-to-the-helm-repo) |

1. Get the chart version from the charts downloaded in [3.10.3](#3103-download-the-ibm-licensing-helm-charts). The `ibm-licensing` and `ibm-licensing-cluster-scoped` charts are released with the same version.
```bash
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
swh-charts/ibm-licensing               	4.2.26+20261015.180257.0	           	...
swh-charts/ibm-licensing-cluster-scoped	4.2.26+20261015.180257.0	           	...
```
Confirm that `${LICENSING_CHART_VERSION}` is available for both charts. Each command must list one row. `helm search repo` exits with 0 even when nothing matches, so check the output: `No results found` means the chart or version is missing, and you need to push it as described in [3.10.4](#3104-push-helm-charts-to-the-helm-repo) before continuing.
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
  version: 4.2.26+20261015.180257.0

namespaceScoped:
  appName: ibm-licensing
  repoURL: "https://raw.github.com/jhwhenry/gitops-charts/main/softwarehub"
  chart: ibm-licensing
  version: 4.2.26+20261015.180257.0
  values: |
    ibmLicensing:
      namespace: ibm-licensing
      watchNamespace: ibm-licensing,cpd-instance
```

**Note:**
- The generated `repoURL` makes Argo CD pull the licensing charts from your own Helm repo (`$HELM_REPO_URL`) instead of the public IBM Helm repo, which is the default when `repoURL` is not set. The charts must therefore be pushed there first, as in [3.10.4](#3104-push-helm-charts-to-the-helm-repo).
- The tool does not contact the Helm repo. It only writes the file, so it cannot tell whether the chart versions exist there. Step 1 confirms the `.tgz` files are in `$HELM_CHARTS_DIR`, and step 2 confirms the Helm repo serves them.

### 3.12 Commit and push applicationset manifests and helm values configuration files to Git repo


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

### 3.13 Apply ApplicationSets
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

