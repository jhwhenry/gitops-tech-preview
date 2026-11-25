#!/usr/bin/env bash
#
# Download the IBM Licensing Helm charts (ibm-licensing and ibm-licensing-cluster-scoped)
# for one version from the public IBM charts repo:
#   https://github.com/IBM/charts/tree/master/repo/ibm-helm
#
# The chart file names carry a build suffix, for example
#   ibm-licensing-4.2.25+20260916.194642.0.tgz
# so the script resolves the full file names from the repo index.yaml. You can pass either
# the short version (4.2.25) or the full version (4.2.25+20260916.194642.0).
#
# Usage: tools/download_licensing_charts.sh [-d TARGET_DIR] [-l] VERSION
#   VERSION        (required) chart version, e.g. 4.2.25 or 4.2.25+20260916.194642.0
#
# Options:
#   -d TARGET_DIR  directory to save the charts in [$HELM_CHARTS_DIR, else the current directory]
#   -l             list the versions available in the repo and exit (VERSION is not needed)
#   -h, --help     show this help
#
# Environment overrides (defaults in brackets):
#   CHARTS_BASE_URL [https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm]
#
# After downloading, regenerate the Helm repo index (helm repo index ... --merge) and push the charts.

set -euo pipefail

CHARTS_BASE_URL="${CHARTS_BASE_URL:-https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm}"
CHARTS=(ibm-licensing ibm-licensing-cluster-scoped)
TARGET_DIR="${HELM_CHARTS_DIR:-.}"
LIST_ONLY=false

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -d) [[ $# -ge 2 ]] || die "-d requires a directory"; TARGET_DIR="$2"; shift ;;
    -l) LIST_ONLY=true ;;
    -*) die "unknown option: $1" ;;
    *) break ;;
  esac
  shift
done

# Only https downloads, with certificate validation and timeouts.
[[ "$CHARTS_BASE_URL" =~ ^https://[A-Za-z0-9._~/:%+@-]+$ ]] || die "CHARTS_BASE_URL must be an https URL: $CHARTS_BASE_URL"
CHARTS_BASE_URL="${CHARTS_BASE_URL%/}"
CURL=(curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --connect-timeout 15 --max-time 300)

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "Fetching ${CHARTS_BASE_URL}/index.yaml"
"${CURL[@]}" -o "$TMP_DIR/index.yaml" "${CHARTS_BASE_URL}/index.yaml" || die "cannot download index.yaml"

# All chart file names for one chart, e.g. ibm-licensing-4.2.25+20260916.194642.0.tgz
list_files() {
  grep -oE "/${1}-[0-9]+\.[0-9]+\.[0-9]+(\+[0-9A-Za-z.]+)?\.tgz" "$TMP_DIR/index.yaml" | sed 's#^/##' | sort -uV
}

if $LIST_ONLY; then
  for chart in "${CHARTS[@]}"; do
    echo "== ${chart}"
    list_files "$chart"
  done
  exit 0
fi

(( $# == 1 )) || die "exactly 1 argument is required: VERSION (got $#); see --help"
VERSION="$1"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9A-Za-z.]+)?$ ]] || die "invalid version: $VERSION (expected 4.2.25 or 4.2.25+20260916.194642.0)"

# Resolve every file name first so nothing is downloaded unless both charts exist.
FILES=()
for chart in "${CHARTS[@]}"; do
  match=""
  while IFS= read -r f; do
    ver="${f#"${chart}-"}"; ver="${ver%.tgz}"
    if [[ "$ver" == "$VERSION" || "$ver" == "${VERSION}+"* ]]; then match="$f"; fi
  done < <(list_files "$chart")
  [[ -n "$match" ]] || die "no ${chart} chart found for version ${VERSION}; run with -l to list the available versions"
  FILES+=("$match")
done

mkdir -p "$TARGET_DIR"
for f in "${FILES[@]}"; do
  log "Downloading ${f}"
  # Fixed file name in the URL: the "+" in the version is valid in a URL path.
  "${CURL[@]}" -o "$TMP_DIR/$f" "${CHARTS_BASE_URL}/${f}" || die "download failed: ${f}"
  tar tzf "$TMP_DIR/$f" >/dev/null 2>&1 || die "not a valid gzip archive: ${f}"
  mv -f "$TMP_DIR/$f" "$TARGET_DIR/$f"
  log "Saved ${TARGET_DIR}/${f}"
done

log "Done. Downloaded ${#FILES[@]} charts to ${TARGET_DIR}"
