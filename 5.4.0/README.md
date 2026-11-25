# ArgoCD ApplicationSets for Release 5.4.0

This file documents the dependency ordering for SWH services, the generated files, and the steps to deploy them.

## Dependency Levels

The levels below reflect dependency depth — components at lower levels are foundational and must be healthy before higher-level components can function correctly.

### Level 1

- ibm_pg_operator
- zen
- ibm_usage_metering
- cpd_platform
- postgresql
- cpfs

### Level 2

- platform-config

### Level 3

- opencontent_opensearch

### Level 4

- ccs

### Level 5

- ws_pipelines
- datastage_ent_plus

## Component Dependencies

This section shows the dependencies for each component. Only components with dependencies are listed.

### ws_pipelines

**Dependencies:**
- opencontent_opensearch
- postgresql
- ccs

### datastage_ent_plus

**Dependencies:**
- opencontent_opensearch
- postgresql
- ccs

### ccs

**Dependencies:**
- opencontent_opensearch
- postgresql



## Generated Files

**Output Directory:** `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/appsets/5.4.0`

### ApplicationSet YAMLs

- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/appsets/5.4.0/applicationsets/cluster-scoped-appset.yaml`
- `/opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/appsets/5.4.0/applicationsets/namespace-scoped-appset.yaml`

### Configuration Files (paths relative to repository root)

- `5.4.0/values-config/global-values-config.yaml`
- `5.4.0/values-config/apps-config/*-config.yaml`
- `5.4.0/README.md`

## Next Steps

1. Review the generated files
2. Commit and push configuration files to your Git repository:
   ```bash
   git add 5.4.0/
   git commit -m "Add SWH 5.4.0 configuration"
   git push
   ```
3. Apply the cluster-scoped ApplicationSet, then confirm its Applications have been generated:
   ```bash
   oc apply -f /opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/appsets/5.4.0/applicationsets/cluster-scoped-appset.yaml
   oc get applications -n openshift-gitops -l resource-scope=cluster-scoped
   ```
4. Auto sync is disabled, so the generated Applications stay `OutOfSync` until you sync them manually. Sync the cluster-scoped Applications and wait until they are synced and healthy (for example `argocd app sync <app>` or from the ArgoCD UI). The sync should follow the dependency levels shown above: sync and wait for the Applications at each level to be healthy before moving to the next level.
5. Once the cluster-scoped Applications are healthy, apply the namespace-scoped ApplicationSet, then confirm its Applications have been generated:
   ```bash
   oc apply -f /opt/ibm/argocd/cpd-cli-workspace/olm-utils-workspace/work/appsets/5.4.0/applicationsets/namespace-scoped-appset.yaml
   oc get applications -n openshift-gitops -l resource-scope=namespace-scoped
   ```
6. Sync the namespace-scoped Applications and wait until they are synced and healthy (for example `argocd app sync <app>` or from the ArgoCD UI). The sync should follow the dependency levels shown above: sync and wait for the Applications at each level to be healthy before moving to the next level.
