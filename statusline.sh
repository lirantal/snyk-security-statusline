#!/usr/bin/env bash
# =============================================================================
# Snyk Security Statusline for Claude Code
# =============================================================================
# Displays live vulnerability status for your project while coding with Claude.
#
# Output format:
#   🔒 snyk │ ✔ no issues │ my-project · 2m ago
#   🔒 snyk │ ✘ 6 vulns (6 fixable) │ H:4 M:2 │ test-project · 5m ago ⟳
#
# Configuration (environment variables):
#   SNYK_BIN              Path to snyk binary        (default: snyk)
#   SNYK_STATUSLINE_TTL   Seconds between scans      (default: 300)
#   SNYK_SHOW_LOW         Show low severity count     (default: false)
#   SNYK_SCAN_ARGS        Extra args for snyk test    (default: "")
# =============================================================================

set -uo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SNYK_BIN="${SNYK_BIN:-snyk}"
CACHE_TTL="${SNYK_STATUSLINE_TTL:-300}"
SHOW_LOW="${SNYK_SHOW_LOW:-false}"
SNYK_SCAN_ARGS="${SNYK_SCAN_ARGS:-}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/snyk-statusline"

# ─── ANSI colors (RGB) ────────────────────────────────────────────────────────
R=$'\033[0m'
RED=$'\033[38;2;255;85;85m'
ORANGE=$'\033[38;2;255;165;0m'
YELLOW=$'\033[38;2;255;215;0m'
GREEN=$'\033[38;2;80;250;123m'
BLUE=$'\033[38;2;100;170;255m'
DIM=$'\033[38;2;128;128;128m'
WHITE=$'\033[38;2;220;220;220m'
SEP="${DIM}│${R}"

# ─── Read Claude session data from stdin ──────────────────────────────────────
SESSION=$(cat)
# Available session fields (for future use):
#   model, contextWindowPercent, sessionCost, gitBranch, worktreeName, vimMode
# Example: MODEL=$(printf '%s' "$SESSION" | jq -r '.model // empty')

# ─── Determine project root ───────────────────────────────────────────────────
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT=$(basename "$GIT_ROOT")

# ─── Cache paths ─────────────────────────────────────────────────────────────
mkdir -p "$CACHE_DIR"
# Hash the project path to create a unique, stable cache key
PATH_HASH=$(printf '%s' "$GIT_ROOT" | cksum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/${PATH_HASH}.json"
LOCK_DIR="$CACHE_DIR/${PATH_HASH}.lock"      # atomic mkdir-based lock
ERR_FILE="$CACHE_DIR/${PATH_HASH}.err"
META_FILE="$CACHE_DIR/${PATH_HASH}.meta"     # stores scan metadata
NOSCAN_FILE="$CACHE_DIR/${PATH_HASH}.noscan" # sentinel: snyk exit 3 (no supported manifest)

# ─── Helpers ─────────────────────────────────────────────────────────────────
cache_age_seconds() {
    # Consider both the result cache and the noscan sentinel as "fresh" states
    local file
    if   [[ -f "$CACHE_FILE"  ]]; then file="$CACHE_FILE"
    elif [[ -f "$NOSCAN_FILE" ]]; then file="$NOSCAN_FILE"
    else printf '999999'; return
    fi
    local mtime now
    mtime=$(stat -c %Y "$file" 2>/dev/null \
         || stat -f %m "$file" 2>/dev/null \
         || printf '0')
    now=$(date +%s)
    printf '%d' $(( now - mtime ))
}

fmt_age() {
    local s=$1
    if   (( s < 60 ));   then printf '%ds' "$s"
    elif (( s < 3600 )); then printf '%dm' "$(( s / 60 ))"
    else                      printf '%dh' "$(( s / 3600 ))"
    fi
}

# ─── Background scan ─────────────────────────────────────────────────────────
# Uses atomic mkdir-based locking so only one scan runs at a time across all
# open terminal tabs / Claude Code windows for the same project.
trigger_scan_bg() {
    mkdir "$LOCK_DIR" 2>/dev/null || return  # already running

    (
        # Ensure lock is always released on exit
        trap 'rm -rf "$LOCK_DIR"' EXIT

        cd "$GIT_ROOT"
        local tmp="$CACHE_FILE.tmp"

        # Run snyk test; capture exit code explicitly:
        #   0 = no vulns, 1 = vulns found (both produce valid JSON), 2 = error, 3 = no manifest
        local exit_code=0
        # shellcheck disable=SC2086
        "$SNYK_BIN" test --json $SNYK_SCAN_ARGS > "$tmp" 2>"$ERR_FILE" || exit_code=$?

        if (( exit_code == 3 )); then
            # No supported project/manifest found in this directory
            printf '%d' "$exit_code" > "$NOSCAN_FILE"
            rm -f "$tmp"
        elif [[ -s "$tmp" ]] && jq -e '.vulnerabilities' "$tmp" &>/dev/null; then
            # Valid scan result (exit 0 or 1)
            rm -f "$NOSCAN_FILE"  # clear stale noscan sentinel if project gained a manifest
            mv "$tmp" "$CACHE_FILE"
            printf '%s' "$(date +%s)" > "$META_FILE"
        else
            rm -f "$tmp"  # partial/unrecognised output — leave state unchanged
        fi
    ) &>/dev/null &
    disown
}

# ─── Check scan freshness & trigger if needed ─────────────────────────────────
AGE=$(cache_age_seconds)
(( AGE > CACHE_TTL )) && trigger_scan_bg
SCANNING=$( [[ -d "$LOCK_DIR" ]] && printf 'true' || printf 'false' )
SPIN=$( $SCANNING && printf " ${DIM}⟳${R}" || printf '' )

# ─── No result cache: show transient or terminal state ───────────────────────
if [[ ! -f "$CACHE_FILE" ]]; then
    if $SCANNING; then
        printf '%s🔒 snyk%s %s %s%s%s scanning deps...%s\n' \
            "$BLUE" "$R" "$SEP" "$WHITE" "$PROJECT" "$DIM" "$R"
    elif [[ -f "$NOSCAN_FILE" ]]; then
        # snyk test exited 3: no supported manifest in this directory
        printf '%s🔒 snyk%s %s %sno deps to scan%s\n' \
            "$BLUE" "$R" "$SEP" "$DIM" "$R"
    elif [[ -s "$ERR_FILE" ]] && grep -qi 'auth\|token\|login\|authenticate' "$ERR_FILE" 2>/dev/null; then
        printf '%s🔒 snyk%s %s %s⚠ auth required%s  run: snyk auth\n' \
            "$BLUE" "$R" "$SEP" "$ORANGE" "$R"
    else
        printf '%s🔒 snyk%s %s %s%s%s initializing...%s\n' \
            "$BLUE" "$R" "$SEP" "$WHITE" "$PROJECT" "$DIM" "$R"
    fi
    exit 0
fi

# ─── Parse cached results (single jq call for efficiency) ────────────────────
IFS='|' read -r OK TOTAL PROJECT_NAME C H M L FIXABLE < <(
    jq -r '[
        (.ok // false | tostring),
        (.uniqueCount // 0 | tostring),
        (.projectName // "unknown"),
        ([.vulnerabilities[]? | select(.severity == "critical")] | length | tostring),
        ([.vulnerabilities[]? | select(.severity == "high")]     | length | tostring),
        ([.vulnerabilities[]? | select(.severity == "medium")]   | length | tostring),
        ([.vulnerabilities[]? | select(.severity == "low")]      | length | tostring),
        ([.vulnerabilities[]? | select(.isUpgradable == true or .isPatchable == true)] | length | tostring)
    ] | join("|")' "$CACHE_FILE" 2>/dev/null || printf 'false|0|unknown|0|0|0|0|0'
)

# Use scanned project name if it matches our project (verify we're reading the right cache)
[[ "$PROJECT_NAME" != "unknown" ]] && PROJECT="$PROJECT_NAME"

# ─── Build vulnerability status ───────────────────────────────────────────────
if [[ "$OK" == "true" ]] || (( TOTAL == 0 )); then
    VULN="${GREEN}✔ no issues${R}"
else
    # Plural helper
    [[ "$TOTAL" == "1" ]] && NOUN="vuln" || NOUN="vulns"
    VULN="${RED}✘ ${TOTAL} ${NOUN}${R}"
    (( FIXABLE > 0 )) && VULN+=" ${DIM}(${FIXABLE} fixable)${R}"
fi

# ─── Build severity breakdown (only non-zero counts shown) ───────────────────
SEV=""
(( C > 0 )) && SEV+="${RED}C:${C}${R} "
(( H > 0 )) && SEV+="${ORANGE}H:${H}${R} "
(( M > 0 )) && SEV+="${YELLOW}M:${M}${R} "
[[ "$SHOW_LOW" == "true" ]] && (( L > 0 )) && SEV+="${DIM}L:${L}${R} "
SEV="${SEV% }"  # trim trailing space

# ─── Build project + age segment ──────────────────────────────────────────────
AGE_STR=$(fmt_age "$AGE")
PROJ="${WHITE}${PROJECT}${R} ${DIM}· ${AGE_STR} ago${R}"

# ─── Compose final output line ────────────────────────────────────────────────
printf '%s🔒 snyk%s %s %s' "$BLUE" "$R" "$SEP" "$VULN"
[[ -n "$SEV" ]] && printf ' %s %s' "$SEP" "$SEV"
printf ' %s %s%s\n' "$SEP" "$PROJ" "$SPIN"
