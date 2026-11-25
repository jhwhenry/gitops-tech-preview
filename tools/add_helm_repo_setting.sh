#!/usr/bin/env bash
#
# Add the Helm repo setting (repoURL) to the apps-config service config files
# (<RELEASE>/values-config/apps-config/*-config.yaml).
#
# For every *.yaml / *.yml file directly inside CONFIG_DIR, and for each of the
# "clusterScoped" and "namespaceScoped" sections that exists in the file:
#   - if the section already has a repoURL property, it is left untouched;
#   - otherwise   repoURL: "<HELM_REPO_URL>"   is added to the section, right
#     after its appName line (or right after the section header if there is none).
# Files are only rewritten when something was added, so re-running is safe.
#
# Usage: tools/add_helm_repo_setting.sh CONFIG_DIR HELM_REPO_URL
#   CONFIG_DIR     (required) folder containing the service config yaml files
#   HELM_REPO_URL  (required) https URL of your Helm repo, written as repoURL
#
# Options:
#   -h, --help     show this help

set -euo pipefail

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
(( ${#POSITIONAL[@]} == 2 )) || die "exactly 2 arguments are required: CONFIG_DIR HELM_REPO_URL (got ${#POSITIONAL[@]}); see --help"

CONFIG_DIR="${POSITIONAL[0]%/}"
HELM_REPO_URL="${POSITIONAL[1]%/}"

[[ -d "$CONFIG_DIR" ]] || die "not a directory: $CONFIG_DIR"
# HTTPS only; the character allowlist keeps the value safe to write into YAML.
[[ "$HELM_REPO_URL" =~ ^https://[A-Za-z0-9._~/:%+@-]+$ ]] || die "invalid HELM_REPO_URL (must be an https URL): $HELM_REPO_URL"

# Prints the file with repoURL added where missing. Exit status is always 0;
# the caller compares the output with the original to detect changes.
add_repo_url() {
  REPO_URL="$HELM_REPO_URL" awk '
    function finalize(   s) {
      for (s in hdr) {
        if (has[s]) continue
        if (s in appLine) insertAfter[appLine[s]] = ind[s] "repoURL: \"" ENVIRON["REPO_URL"] "\""
        else insertAfter[hdr[s]] = (ind[s] == "" ? "  " : ind[s]) "repoURL: \"" ENVIRON["REPO_URL"] "\""
      }
    }
    # Pass 1: find the sections and what they already contain.
    NR == FNR {
      if ($0 ~ /^(clusterScoped|namespaceScoped):[ \t]*(#.*)?$/) {
        sec = $0; sub(/:.*/, "", sec); hdr[sec] = FNR; ind[sec] = ""; next
      }
      if ($0 ~ /^[^ \t#]/) { sec = ""; next }          # any other top-level key ends the section
      if (sec == "" || $0 ~ /^[ \t]*(#.*)?$/) next      # outside a section, blank or comment line
      match($0, /^[ \t]*/); lead = substr($0, 1, RLENGTH)
      if (ind[sec] == "") ind[sec] = lead                # indentation of the first property
      if (lead != ind[sec]) next                         # ignore nested content (e.g. inside values)
      if ($0 ~ /^[ \t]*repoURL:/) has[sec] = 1
      else if ($0 ~ /^[ \t]*appName:/ && !(sec in appLine)) appLine[sec] = FNR
      next
    }
    # Pass 2: copy the file, adding the missing lines.
    FNR == 1 { finalize() }
    { print }
    FNR in insertAfter { print insertAfter[FNR] }
  ' "$1" "$1"
}

shopt -s nullglob
FILES=("$CONFIG_DIR"/*.yaml "$CONFIG_DIR"/*.yml)
(( ${#FILES[@]} > 0 )) || die "no yaml files found in $CONFIG_DIR"

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

updated=0
unchanged=0
for f in "${FILES[@]}"; do
  [[ -s "$f" ]] || { log "skip (empty): $f"; continue; }
  add_repo_url "$f" > "$TMP_FILE"
  if cmp -s "$f" "$TMP_FILE"; then
    log "unchanged: $f"
    unchanged=$((unchanged + 1))
  else
    cat "$TMP_FILE" > "$f"   # keep the original file mode and ownership
    log "updated:   $f"
    updated=$((updated + 1))
  fi
done

log "Done: ${updated} file(s) updated, ${unchanged} unchanged. Review, commit and push the changes."
