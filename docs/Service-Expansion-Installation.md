# Argo CD ApplicationSet-Based watsonx.data and watsonx.ai Installation
This document aims to introduce the installation of watsonx.data and watsonx.ai following a successfull IBM Software Hub installation.

## Assumption
> ⚠️ **Important:** this example is based on the following assumptions.
- The IBM Software Hub 5.4.0 patch8 have been installed successfully based on the Argo CD applicationsets following the deployment pattern introducced by the `gitops-tech-preview` Git repo.
- watsonx.data and watsonx.ai are to be installed on the same version as service expansition installation.
- The workstation, environment variables file, Git repo, Helm repo and Argo CD settings used by the IBM Software Hub Argo CD deployment will be reused. 
- Sizing and resource planning for the new services have been done.
- Images have been mirrored to the private image registry.
- Prerequisite software have been installed. [Installing prerequisite software](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=cluster-installing-prerequisite-software)


## Installation 
### 1. Update existing environment variables file

-  Edit the exising environment variable file named `cpd_vars.sh` in  `$ARGOCD_DIR` 

```bash
export ARGOCD_DIR=/opt/ibm/argocd
vi $ARGOCD_DIR/cpd_vars.sh
```

Add `watsonx_data` and `watsonx_ai` to the `COMPONENTS`.

With the mofification, the `cpd_vars.sh` looks like below.

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
export COMPONENTS=ibm-licensing,cpfs,cpd_platform,datastage_ent_plus,ws_pipelines,watsonx_data,watsonx_ai
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

-  Source the environment variable
```bash
source cpd_vars.sh
```

**Note:** Run `source $ARGOCD_DIR/cpd_vars.sh` again in every new terminal.

### 2. Log into the OCP cluster
```bash
${OC_LOGIN}
${CPDM_OC_LOGIN}
```

### 3. Install prerequisite software

#### 3.1 Install GPU operators required by watsonx.ai

Install GPU operators that support the management of the NVIDIA software components which are needed to provision GPUs.

- Option 1 - Follow the procedures in IBM documentation[Installing GPU operators](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=software-installing-operators-services-that-require-gpus)

- Option 2 - Try [GPU GitOps for OpenShift](https://github.com/americas-launch/gpu-gitops)

#### 3.2 Install OpenShift AI required by watsonx.ai
watsonx.ai uses Inference foundation models, you must install Red Hat OpenShift AI to start and serve the models.

- Option 1 - Follow the procedures in IBM documentation[Installing Red Hat OpenShift AI](https://www.ibm.com/docs/en/software-hub/5.4.x?topic=software-installing-red-hat-openshift-ai)

- Option 2 - Try the procedures in the TechxChange community blog [GitOps-Driven Installation of Red Hat OpenShift AI on IBM Fusion with Argo CD](https://community.ibm.com/community/user/blogs/harichandana-kotha/2026/02/23/gitops-driven-installation-rhoai)

### 4. Download the CASE packages
Download the CASE packages for the components.

```bash
export COMPONENTS=watsonx_data,watsonx_ai

cpd-cli manage case-download --components=$COMPONENTS \
--release=$VERSION --patch_id=$PATCH_ID
```

Validate the CASE packages downloaded to the cases folder successfully.

```bash
export WORK_DIR=$(podman inspect olm-utils-play-v4 | jq -r '.[0].Mounts' |jq -r '.[] | select(.Destination == "/tmp/work") | .Source')
ls -alrt $WORK_DIR/offline/${VERSION}/.ibm-pak/data/cases
```

### 5. Clone the `gitops-charts` Helm repo to your local workstation

The example reuses the `gitops-charts` repo used by IBM Software Hub deployment. The `gitops-charts` repo is supposed to exist in the 
`ARGOCD_DIR`. Clone the `gitops-charts` repo if it doesn't exist.

```bash
cd $ARGOCD_DIR
git clone https://github.com/jhwhenry/gitops-charts.git
```

### 6. Clone the `gitops-tech-preview` git repo to your local workstation

The example reuses the `gitops-tech-preview` repo used by IBM Software Hub deployment. The `gitops-tech-preview` repo is supposed to exist in the `ARGOCD_DIR`. Clone the `gitops-tech-preview` repo if it doesn't exist.

```bash
cd $ARGOCD_DIR
git clone https://github.com/jhwhenry/gitops-tech-preview.git
cd $ARGOCD_DIR/gitops-tech-preview
git checkout $ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH
git branch --show-current
```

The last command must print the value of `ARGOCD_APPSET_CONFIG_GIT_REPO_BRANCH` (`5.4.0_Patch8` in this example).

### 7. Create install-options.yaml
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

```bash
export COMPONENTS=watsonx_data,watsonx_ai
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
  imagePullPrefix: ${PRIVATE_REGISTRY_LOCATION}
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
  watsonxAi:
    scaleConfig: small
  watsonxData:
    enable_lite_milvus: false
    scaleConfig: small
EOF

```

Copy the `install-options.yaml` to the `cpd-cli-workspace/olm-utils-workspace/work` directory.

```bash
export WORK_DIR=$(podman inspect olm-utils-play-v4 | jq -r '.[0].Mounts' |jq -r '.[] | select(.Destination == "/tmp/work") | .Source')

cp install-options.yaml $WORK_DIR/install-options.yaml

chmod 644 ${WORK_DIR}/install-options.yaml
```

### 8. Run create-argo-appsets command to create Argo CD applicationsets
```bash
cpd-cli manage create-argo-appsets \
    --install_option_file=${WORK_DIR}/install-options.yaml \
    --log_level=debug
```

**Note:** The `--install_option_file` flag requires your local file path (e.g., `/path/to/cpd-cli-workspace/olm-utils-workspace/work/install-options.yaml`), not the container's internal path (`/tmp/work/install-options.yaml`).

The above command will perform the following steps:

- Validate Configuration: Verify all required fields and component dependencies

- Generate Argo CD Resources: Create ApplicationSet manifests, Helm values configuration files and generate Helm charts.


**Generated Output:**

The command generates the following directory structure in `cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/<release version>` (`$WORK_DIR/ArgoCD/${VERSION}`):

```text
[root@bastion-1 appsets]# pwd
/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD
[root@bastion-1 appsets]# tree .
.
└── 5.4.0
    ├── appsets
    │   ├── applicationsets
    │   │   ├── cluster-scoped-appset.yaml
    │   │   └── namespace-scoped-appset.yaml
    │   ├── README.md
    │   └── values-config
    │       ├── apps-config
    │       │   ├── analyticsengine-config.yaml
    │       │   ├── ccs-config.yaml
    │       │   ├── cpd-platform-config.yaml
    │       │   ├── datarefinery-config.yaml
    │       │   ├── ibm-common-service-operator-config.yaml
    │       │   ├── ibm-iam-operator-config.yaml
    │       │   ├── ibm-pg-operator-config.yaml
    │       │   ├── ibm-redis-cp-config.yaml
    │       │   ├── ibm-usage-metering-config.yaml
    │       │   ├── opencontent-opensearch-config.yaml
    │       │   ├── platform-config-config.yaml
    │       │   ├── postgresql-config.yaml
    │       │   ├── watsonx-ai-config.yaml
    │       │   ├── watsonx-ai-ifm-config.yaml
    │       │   ├── watsonx-data-config.yaml
    │       │   ├── wml-config.yaml
    │       │   ├── ws-config.yaml
    │       │   ├── ws-runtimes-config.yaml
    │       │   └── zen-config.yaml
    │       └── global-values-config.yaml
    └── charts
        ├── analyticsengine-5.4.8+20260927.003702.2995.tgz
        ├── analyticsengine-cluster-scoped-5.4.8+20260927.003702.2995.tgz
        ├── ccs-13.0.8+20261013.142720.198.tgz
        ├── ccs-cluster-scoped-13.0.8+20261013.142720.198.tgz
        ├── cpd-platform-5.10.8+20260929.105344.9.tgz
        ├── cpd-platform-cluster-scoped-5.10.8+20260929.105344.9.tgz
        ├── datarefinery-13.0.8+20260928.214227.474.tgz
        ├── datarefinery-cluster-scoped-13.0.8+20260928.214227.474.tgz
        ├── ibm-common-service-operator-4.19.3+20260915.101245.0.tgz
        ├── ibm-common-service-operator-cluster-scoped-4.19.3+20260915.101245.0.tgz
        ├── ibm-iam-operator-4.18.2+20260909.101104.0.tgz
        ├── ibm-iam-operator-cluster-scoped-4.18.2+20260909.101104.0.tgz
        ├── ibm-pg-operator-28.3.3+20260625.144015.538.tgz
        ├── ibm-pg-operator-cluster-scoped-28.3.3+20260625.144014.538.tgz
        ├── ibm-redis-cp-1.4.1+20260902.142404.332.tgz
        ├── ibm-redis-cp-cluster-scoped-1.4.1+20260902.142404.332.tgz
        ├── ibm-usage-metering-1.0.8+20260916.194642.0.tgz
        ├── ibm-usage-metering-cluster-scoped-1.0.8+20260916.194642.0.tgz
        ├── opencontent-opensearch-1.5.3+20250905.120936.tgz
        ├── opencontent-opensearch-cluster-scoped-1.5.3+20250905.120936.tgz
        ├── platform-config-5.10.8+20260929.105344.9.tgz
        ├── postgresql-5.40.2+20261016.171231.346.tgz
        ├── postgresql-cluster-scoped-5.40.2+20261016.171231.346.tgz
        ├── watsonx-ai-13.0.8+20260925.143128.32.tgz
        ├── watsonx-ai-cluster-scoped-13.0.8+20260925.143128.32.tgz
        ├── watsonx-ai-ifm-13.0.8+20261009.135858.71.tgz
        ├── watsonx-ai-ifm-cluster-scoped-13.0.8+20261009.135858.71.tgz
        ├── watsonx-data-7.0.5+20260729.182904.296.tgz
        ├── watsonx-data-cluster-scoped-7.0.5+20260729.182904.296.tgz
        ├── wml-13.0.4+20260928.154042.93.tgz
        ├── wml-cluster-scoped-13.0.4+20260928.154042.93.tgz
        ├── ws-13.0.8+20260925.125219.26.tgz
        ├── ws-cluster-scoped-13.0.8+20260925.125219.26.tgz
        ├── ws-runtimes-13.0.3+20260925.084230.71.tgz
        ├── ws-runtimes-cluster-scoped-13.0.3+20260925.084230.71.tgz
        ├── zen-6.10.8+20260929.112719.45.tgz
        └── zen-cluster-scoped-6.10.8+20260929.112719.45.tgz

7 directories, 60 files
```
A README document, such as `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/appsets/README.md`, will also be generated.

> ⚠️ **Important:**  Review the generated applicationSet manifests and Helm values configuration files before moving to the next step.
- Review the `cluster-scoped-appset.yaml` and `namespace-scoped-appset.yaml` in the `ArgoCD/5.4.0/appsets/values-config` folder.
- Review the Helm **global** values configuration file `global-values-config.yaml` in the `ArgoCD/5.4.0/appsets/values-config` folder.
Example of `global-values-config.yaml`:

```bash
global:
  licenseAccept: true
  crAdoption: false
  releaseVersion: 5.4.0
  components:
    - ibm_usage_metering
    - watsonx_data
    - analyticsengine
    - ws_runtimes
    - platform-config
    - wml
    - postgresql
    - opencontent_opensearch
    - watsonx_ai
    - ccs
    - cpfs
    - ibm_redis_cp
    - ibm_pg_operator
    - cpd_platform
    - datarefinery
    - zen
    - ws
    - watsonx_ai_ifm

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
Example of `watsonx-ai-config.yaml`:
```bash
# Service specific Configuration
# Combined cluster-scoped and namespace-scoped configuration

componentID: watsonx-ai

# Cluster-scoped chart configuration
clusterScoped:
  appName: watsonx-ai-cluster
  chart: watsonx-ai-cluster-scoped
  version: 13.0.8+20260925.143128.32

# Namespace-scoped chart configuration
namespaceScoped:
  appName: watsonx-ai
  chart: watsonx-ai
  version: 13.0.8+20260925.143128.32
  values: |
    watsonxAi:
      scaleConfig: small
~                            
```

### 9 Prepare Helm charts and push them to the Helm repo
#### 9.1 Specify the Helm charts directory
Specify the target directory which will store the Helm charts. It's recommended using the absolute path of the `gitops-charts/softwarehub` directory created by the git clone command in the 3.11 step.
```bash
export HELM_CHARTS_DIR=$ARGOCD_DIR/gitops-charts/softwarehub
```

#### 9.2 Move the generated Helm charts to Helm charts directory
Move the Helm charts generated in the step 8 to Helm charts directory.
```bash
cp -r $WORK_DIR/ArgoCD/${VERSION}/charts/* $HELM_CHARTS_DIR
```

#### 9.3 Push Helm charts to the Helm repo
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
git commit -m "Add watsonx.data and watsonx.ai charts based on IBM Software Hub 5.4.0 Patch 8"
git push origin main
```

### 10. Commit and push applicationset manifests and helm values configuration files to Git repo

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

### 11. Apply ApplicationSets
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


## Monitor ApplicationSet Generation

Monitor the ApplicationSets and the Applications they generate:

### Check ApplicationSets status
```bash
oc get applicationsets -n openshift-gitops
```

### Check generated Applications
```bash
oc get applications -n openshift-gitops
```

### Watch Applications in real-time
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
