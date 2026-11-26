# ArgoCD ApplicationSets for Release 5.4.0

This file documents the dependency ordering for SWH services, the generated files, and the steps to deploy them.

## Dependency Levels

The levels below reflect dependency depth — components at lower levels are foundational and must be healthy before higher-level components can function correctly.

### Level 1

- zen
- cpd_platform
- cpfs
- ibm_pg_operator
- postgresql
- ibm_usage_metering

### Level 2

- platform-config

### Level 3

- opencontent_rabbitmq
- analyticsengine
- opencontent_opensearch
- ibm_redis_cp
- watson_gateway

### Level 4

- ccs
- data_governor

### Level 5

- watsonx_ai_ifm
- watsonx_data

### Level 6

- watson_assistant

### Level 7

- watsonx_orchestrate

## Component Dependencies

This section shows the dependencies for each component. Only components with dependencies are listed.

### analyticsengine

**Dependencies:**
- postgresql

### ccs

**Dependencies:**
- opencontent_opensearch
- postgresql

### data_governor

**Dependencies:**
- opencontent_opensearch

### watsonx_orchestrate

**Dependencies:**
- postgresql
- watson_gateway
- data_governor
- opencontent_opensearch
- ibm_redis_cp
- ccs
- watsonx_ai_ifm
- watson_assistant
- opencontent_rabbitmq
- watsonx_data
- analyticsengine

### watson_assistant

**Dependencies:**
- postgresql
- watson_gateway
- data_governor
- opencontent_opensearch
- ibm_redis_cp
- ccs
- watsonx_ai_ifm

### watsonx_ai_ifm

**Dependencies:**
- opencontent_opensearch
- postgresql
- ccs
- ibm_redis_cp

### watsonx_data

**Dependencies:**
- analyticsengine
- ccs
- opencontent_opensearch
- postgresql



## Generated Files

**Output Directory:** `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/appsets`

### ApplicationSet YAMLs

- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/appsets/applicationsets/cluster-scoped-appset.yaml`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/appsets/applicationsets/namespace-scoped-appset.yaml`

### Configuration Files (git-relative paths)

- `5.4.0/appsets/values-config/global-values-config.yaml`
- `5.4.0/appsets/values-config/apps-config/*-config.yaml`
- `5.4.0/appsets/README.md`

### Helm Charts

Please make sure that these charts are available from your configured helm chart repo (`https://raw.github.com/jhwhenry/gitops-charts/main/softwarehub`):

- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/zen-cluster-scoped-6.10.8+20260929.112719.45.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/zen-6.10.8+20260929.112719.45.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/cpd-platform-cluster-scoped-5.10.8+20260929.105344.9.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/cpd-platform-5.10.8+20260929.105344.9.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/opencontent-rabbitmq-cluster-scoped-1.4.3+20250909.172851.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/opencontent-rabbitmq-1.4.3+20250909.172851.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/analyticsengine-cluster-scoped-5.4.8+20260927.003702.2995.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/analyticsengine-5.4.8+20260927.003702.2995.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-common-service-operator-cluster-scoped-4.19.3+20260915.101245.0.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-common-service-operator-4.19.3+20260915.101245.0.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-iam-operator-cluster-scoped-4.18.2+20260909.101104.0.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-iam-operator-4.18.2+20260909.101104.0.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ccs-cluster-scoped-13.0.8+20261013.142720.198.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ccs-13.0.8+20261013.142720.198.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/opencontent-opensearch-cluster-scoped-1.5.3+20250905.120936.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/opencontent-opensearch-1.5.3+20250905.120936.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/data-governor-cluster-scoped-9.0.2+20261016.144249.496.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/data-governor-9.0.2+20261016.144249.496.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-pg-operator-cluster-scoped-28.3.3+20260625.144014.538.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-pg-operator-28.3.3+20260625.144015.538.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watsonx-orchestrate-cluster-scoped-8.0.4+20261019.111629.22713.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watsonx-orchestrate-8.0.4+20261019.111629.22713.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/platform-config-5.10.8+20260929.105344.9.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watson-assistant-cluster-scoped-5.17.1+20261017.215936.4887.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watson-assistant-5.17.1+20261017.215936.4887.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-redis-cp-cluster-scoped-1.4.1+20260902.142404.332.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-redis-cp-1.4.1+20260902.142404.332.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watsonx-ai-ifm-cluster-scoped-13.0.8+20261009.135858.71.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watsonx-ai-ifm-13.0.8+20261009.135858.71.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watson-gateway-cluster-scoped-2.4.4+20250905.144313.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watson-gateway-2.4.4+20250905.144313.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/postgresql-cluster-scoped-5.40.2+20261016.171231.346.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/postgresql-5.40.2+20261016.171231.346.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-usage-metering-cluster-scoped-1.0.8+20260916.194642.0.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/ibm-usage-metering-1.0.8+20260916.194642.0.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watsonx-data-cluster-scoped-7.0.5+20260729.182904.296.tgz`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/charts/watsonx-data-7.0.5+20260729.182904.296.tgz`

For more information about hosting charts in a helm repo, see https://helm.sh/docs/topics/chart_repository/

## Next Steps

1. Review the generated files:
   ```bash
   cd /opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/appsets
   ```
2. Commit and push configuration files to your Git repository:
   ```bash
   # Navigate to your Git repository
   cd /path/to/your/git/repo

   # Create the release folder if it doesn't exist
   mkdir -p 5.4.0

   # Copy the generated files to your repository
   cp -r /opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/appsets 5.4.0/

   git add 5.4.0/appsets/
   git commit -m "Add SWH 5.4.0 configuration"
   git push
   ```
3. Apply the cluster-scoped ApplicationSet, then confirm its Applications have been generated:
   ```bash
   oc apply -f /opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/appsets/applicationsets/cluster-scoped-appset.yaml
   oc get applications -n openshift-gitops -l resource-scope=cluster-scoped
   ```
4. Auto sync is disabled, so the generated Applications stay `OutOfSync` until you sync them manually. Sync the cluster-scoped Applications and wait until they are synced and healthy (for example `argocd app sync <app>` or from the ArgoCD UI). The sync should follow the dependency levels shown above: sync and wait for the Applications at each level to be healthy before moving to the next level.
5. Once the cluster-scoped Applications are healthy, apply the namespace-scoped ApplicationSet, then confirm its Applications have been generated:
   ```bash
   oc apply -f /opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/ArgoCD/5.4.0/appsets/applicationsets/namespace-scoped-appset.yaml
   oc get applications -n openshift-gitops -l resource-scope=namespace-scoped
   ```
6. Sync the namespace-scoped Applications and wait until they are synced and healthy (for example `argocd app sync <app>` or from the ArgoCD UI). The sync should follow the dependency levels shown above: sync and wait for the Applications at each level to be healthy before moving to the next level.
