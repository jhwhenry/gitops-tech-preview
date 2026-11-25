#!/usr/bin/env bash
# =============================================================================
# extract_helm_charts.sh
#
# Extracts Helm charts from an IBM Software Hub / Argo CD cases source tree
# into a target directory, either as packaged (.tgz) or unpacked chart folders.
#
# Usage:
#   ./extract_helm_charts.sh -s <source_dir> -t <target_dir> -o <1|2>
#
# Options:
#   -s  Source directory (root of the cases tree)
#   -t  Target output directory
#   -o  Operation mode:
#         1 = Copy packaged charts (.tgz) — excludes *-migration-* charts
#         2 = Unpack charts into named folders  — excludes *-migration-* charts
#   -h  Show this help message
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
usage() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
    exit 1
}

log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%dT%H:%M:%S')"
    printf '[%s] [%-5s] %s\n' "$ts" "$level" "$msg" | tee -a "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
SOURCE_DIR=""
TARGET_DIR=""
OPTION=""

while getopts ":s:t:o:h" opt; do
    case "$opt" in
        s) SOURCE_DIR="$OPTARG" ;;
        t) TARGET_DIR="$OPTARG" ;;
        o) OPTION="$OPTARG" ;;
        h) usage ;;
        :) echo "ERROR: Option -${OPTARG} requires an argument." >&2; exit 1 ;;
        \?) echo "ERROR: Unknown option -${OPTARG}." >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Validation of arguments
# ---------------------------------------------------------------------------
if [[ -z "$SOURCE_DIR" || -z "$TARGET_DIR" || -z "$OPTION" ]]; then
    echo "ERROR: -s, -t and -o are all required." >&2
    usage
fi

if [[ "$OPTION" != "1" && "$OPTION" != "2" ]]; then
    echo "ERROR: -o must be 1 (packaged) or 2 (unpacked)." >&2
    exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: Source directory does not exist: $SOURCE_DIR" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Set up log file
# ---------------------------------------------------------------------------
mkdir -p "$TARGET_DIR"

LOG_FILE="${TARGET_DIR}/extract_helm_charts_$(date '+%Y%m%d_%H%M%S').log"

log INFO "=========================================================="
log INFO " Helm Chart Extractor"
log INFO "=========================================================="
log INFO "Source      : $SOURCE_DIR"
log INFO "Target      : $TARGET_DIR"
log INFO "Mode        : $OPTION $([ "$OPTION" = "1" ] && echo '(packaged .tgz)' || echo '(unpacked folders)')"
log INFO "Log file    : $LOG_FILE"
log INFO "=========================================================="

# ---------------------------------------------------------------------------
# Discover all charts/*.tgz files under the source tree
# ---------------------------------------------------------------------------
# Pattern: <source>/<component>/<version>/charts/*.tgz
# Use a while-read loop for bash 3 compatibility (no mapfile).
ALL_CHARTS=()
while IFS= read -r line; do
    ALL_CHARTS+=("$line")
done < <(find "$SOURCE_DIR" -type f -name "*.tgz" -path "*/charts/*.tgz" | sort)

if [[ "${#ALL_CHARTS[@]}" -eq 0 ]]; then
    log WARN "No .tgz files found under $SOURCE_DIR/*/charts/"
    exit 0
fi

log INFO "Total .tgz files found (including migration): ${#ALL_CHARTS[@]}"

# Separate migration charts from regular charts
MIGRATION_CHARTS=()
REGULAR_CHARTS=()
for chart in "${ALL_CHARTS[@]}"; do
    basename_chart="$(basename "$chart")"
    if [[ "$basename_chart" == *"-migration-"* ]]; then
        MIGRATION_CHARTS+=("$chart")
    else
        REGULAR_CHARTS+=("$chart")
    fi
done

log INFO "  Regular charts : ${#REGULAR_CHARTS[@]}"
log INFO "  Migration charts (excluded): ${#MIGRATION_CHARTS[@]}"
for mc in "${MIGRATION_CHARTS[@]}"; do
    log INFO "    SKIP (migration): $(basename "$mc")  [$(dirname "$mc" | sed "s|^$SOURCE_DIR/||")]"
done
log INFO "----------------------------------------------------------"

# ---------------------------------------------------------------------------
# Mode 1: Copy packaged charts (.tgz) to target directory
# ---------------------------------------------------------------------------
copy_packaged() {
    local copied=0
    local failed=0

    for chart in "${REGULAR_CHARTS[@]}"; do
        local name
        name="$(basename "$chart")"
        local dest="${TARGET_DIR}/${name}"

        # Detect collision (two components with identically-named .tgz)
        if [[ -e "$dest" ]]; then
            log WARN "COLLISION — file already exists, overwriting: $name"
        fi

        if cp "$chart" "$dest"; then
            log INFO "COPIED  : $name  →  $TARGET_DIR/"
            (( copied++ )) || true
        else
            log ERROR "FAILED  : $name  (cp returned non-zero)"
            (( failed++ )) || true
        fi
    done

    echo ""
    log INFO "=========================================================="
    log INFO " Summary (Mode 1 — packaged)"
    log INFO "  Expected : ${#REGULAR_CHARTS[@]}"
    log INFO "  Copied   : $copied"
    log INFO "  Failed   : $failed"
    log INFO "  Skipped (migration): ${#MIGRATION_CHARTS[@]}"

    if [[ "$copied" -ne "${#REGULAR_CHARTS[@]}" || "$failed" -gt 0 ]]; then
        log ERROR "VALIDATION FAILED — mismatch detected (expected ${#REGULAR_CHARTS[@]}, copied $copied, failed $failed)"
        log INFO "=========================================================="
        return 1
    fi

    log INFO " VALIDATION PASSED — all regular charts copied successfully"
    log INFO "=========================================================="
}

# ---------------------------------------------------------------------------
# Mode 2: Unpack charts into named folders in target directory
# ---------------------------------------------------------------------------
copy_unpacked() {
    local unpacked=0
    local failed=0

    # Temp workspace inside target dir (not local so the cleanup trap can see it)
    _UNPACK_TMP="$(mktemp -d "${TARGET_DIR}/.extract_tmp_XXXXXX")"
    trap 'rm -rf "$_UNPACK_TMP"' RETURN

    for chart in "${REGULAR_CHARTS[@]}"; do
        local tgz_name
        tgz_name="$(basename "$chart")"

        # Extract chart name by stripping the version+build suffix.
        # Chart archives are named <chart-name>-<semver>[+build].tgz
        # We strip everything from the first digit-led version segment onward.
        # e.g. zen-6.10.5+20260730.tgz  → zen
        #      ibm-common-service-operator-4.19.2+...tgz → ibm-common-service-operator
        local chart_name
        chart_name="$(echo "$tgz_name" | sed 's/-[0-9][^/]*\.tgz$//')"

        local extract_tmp="${_UNPACK_TMP}/${chart_name}"
        mkdir -p "$extract_tmp"

        if ! tar -xzf "$chart" -C "$extract_tmp" 2>>"$LOG_FILE"; then
            log ERROR "EXTRACT FAILED : $tgz_name"
            (( failed++ )) || true
            rm -rf "$extract_tmp"
            continue
        fi

        # After extraction the top-level directory inside the archive is the
        # canonical chart directory name (may differ from our derived chart_name).
        # Use that directory as the authoritative name.
        local extracted_dirs=()
        while IFS= read -r d; do extracted_dirs+=("$d"); done \
            < <(find "$extract_tmp" -mindepth 1 -maxdepth 1 -type d)

        if [[ "${#extracted_dirs[@]}" -ne 1 ]]; then
            log WARN "UNEXPECTED layout in $tgz_name (${#extracted_dirs[@]} top-level dirs); using derived name '$chart_name'"
            local src_dir="$extract_tmp"
        else
            local src_dir="${extracted_dirs[0]}"
            chart_name="$(basename "$src_dir")"
        fi

        local dest="${TARGET_DIR}/${chart_name}"

        if [[ -e "$dest" ]]; then
            log WARN "COLLISION — directory already exists, overwriting: $chart_name/"
            rm -rf "$dest"
        fi

        if cp -r "$src_dir" "$dest"; then
            log INFO "UNPACKED: $tgz_name  →  ${TARGET_DIR}/${chart_name}/"
            (( unpacked++ )) || true
        else
            log ERROR "COPY FAILED : $tgz_name  →  ${TARGET_DIR}/${chart_name}/"
            (( failed++ )) || true
        fi

        rm -rf "$extract_tmp"
    done

    echo ""
    log INFO "=========================================================="
    log INFO " Summary (Mode 2 — unpacked)"
    log INFO "  Expected : ${#REGULAR_CHARTS[@]}"
    log INFO "  Unpacked : $unpacked"
    log INFO "  Failed   : $failed"
    log INFO "  Skipped (migration): ${#MIGRATION_CHARTS[@]}"

    if [[ "$unpacked" -ne "${#REGULAR_CHARTS[@]}" || "$failed" -gt 0 ]]; then
        log ERROR "VALIDATION FAILED — mismatch detected (expected ${#REGULAR_CHARTS[@]}, unpacked $unpacked, failed $failed)"
        log INFO "=========================================================="
        return 1
    fi

    log INFO " VALIDATION PASSED — all regular charts unpacked successfully"
    log INFO "=========================================================="
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
if [[ "$OPTION" == "1" ]]; then
    copy_packaged
else
    copy_unpacked
fi
