#!/usr/bin/env bash
#
# Generate the IBM Licensing config file for the gitops-cpd-config ApplicationSets:
#   <RELEASE>/values-config/apps-config/ibm-licensing-config.yaml
#
# The script only writes that file. Committing, pushing and applying the
# ApplicationSets are left to the caller.
#
# Usage: tools/generate_licensing_config.sh CHART_VERSION INSTANCE_NS HELM_REPO_URL
#   CHART_VERSION  (required) chart version used for both ibm-licensing-cluster-scoped
#                  and ibm-licensing (namespace-scoped), e.g. 4.2.25+20260916.194642.0
#   INSTANCE_NS    (required) CPD instance namespace the License Service also watches
#   HELM_REPO_URL  (required) https URL of your Helm repo hosting the licensing charts,
#                  written as repoURL for both Applications
#
# Options:
#   -h, --help     show this help
#
# Environment overrides (defaults in brackets):
#   RELEASE [5.4.0]   LICENSING_NS [ibm-licensing]

set -euo pipefail

RELEASE="${RELEASE:-5.4.0}"
LICENSING_NS="${LICENSING_NS:-ibm-licensing}"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) POSITIONAL+=("$1") ;;
  esac
  shift
done
(( ${#POSITIONAL[@]} == 3 )) || die "exactly 3 arguments are required: CHART_VERSION INSTANCE_NS HELM_REPO_URL (got ${#POSITIONAL[@]}); see --help"

# The cluster-scoped and namespace-scoped charts are released in lockstep, so one version covers both.
CHART_VERSION="${POSITIONAL[0]}"
INSTANCE_NS="${POSITIONAL[1]}"
HELM_REPO_URL="${POSITIONAL[2]%/}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${REPO_DIR}/${RELEASE}/appsets/values-config/apps-config/ibm-licensing-config.yaml"

[[ -d "$(dirname "$CONFIG_FILE")" ]] || die "not found: $(dirname "$CONFIG_FILE")"

VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9A-Za-z.]+)?$'
[[ "$CHART_VERSION" =~ $VERSION_RE ]] || die "invalid chart version: $CHART_VERSION"
# HTTPS only; the character allowlist keeps the value safe to write into YAML.
[[ "$HELM_REPO_URL" =~ ^https://[A-Za-z0-9._~/:%+@-]+$ ]] || die "invalid HELM_REPO_URL (must be an https URL): $HELM_REPO_URL"
for ns in "$LICENSING_NS" "$INSTANCE_NS"; do
  [[ "$ns" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || die "invalid namespace name: $ns"
done
WATCH_NS="${LICENSING_NS},${INSTANCE_NS}"

cat > "$CONFIG_FILE" <<EOF
# Service specific Configuration
# Combined cluster-scoped and namespace-scoped configuration

componentID: ibm-licensing

# Cluster-scoped chart configuration
clusterScoped:
  appName: ibm-licensing-cluster
  repoURL: "${HELM_REPO_URL}"
  chart: ibm-licensing-cluster-scoped
  version: ${CHART_VERSION}

# Namespace-scoped chart configuration
namespaceScoped:
  appName: ibm-licensing
  repoURL: "${HELM_REPO_URL}"
  chart: ibm-licensing
  version: ${CHART_VERSION}
  values: |
    ibmLicensing:
      namespace: ${LICENSING_NS}
      watchNamespace: ${WATCH_NS}
EOF

log "Generated ${CONFIG_FILE}"
