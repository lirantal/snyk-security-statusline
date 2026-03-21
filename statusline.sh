#!/usr/bin/env bash
# =============================================================================
# Snyk Security Statusline for Claude Code
# =============================================================================
# Displays live vulnerability status for your project while you code with Claude.
# Runs two independent background scans:
#   • snyk test       — open-source dependency vulnerabilities (SCA)
#   • snyk code test  — SAST static analysis of your own source code
#
# Output format:
#   ⬡ snyk │ deps ● C:2 ● H:4 ● M:2 ↑6 │ code ● H:2 ● M:3 ↑4 │ my-project · 5m ⟳
#   ⬡ snyk │ deps ✦ │ code ✦ │ my-app · 2m
#   ⬡ snyk │ deps scanning... │ code ● H:2 ● M:3 │ my-app · 3m ⟳
#   ⬡ snyk │ no deps to scan │ no code to scan │ bare-project
#   ⬡ snyk │ ⚠ auth required  run: snyk auth
#
# Configuration (environment variables):
#   SNYK_BIN              Path to snyk binary        (default: snyk)
#   SNYK_STATUSLINE_TTL   Seconds between scans      (default: 300)
#   SNYK_SHOW_LOW         Show low severity counts    (default: false)
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
# Snyk brand
SNYK=$'\033[38;2;168;85;247m'         # #A855F7 — Snyk electric purple
# Severity (vivid, high-contrast)
CRIT=$'\033[38;2;255;59;48m'          # #FF3B30 — critical red
HIGH=$'\033[38;2;255;149;0m'          # #FF9500 — high orange
MED=$'\033[38;2;255;204;0m'           # #FFCC00 — medium amber
LOW=$'\033[38;2;142;132;168m'         # #8E84A8 — low muted purple-gray
# Status
CLEAN=$'\033[38;2;52;211;153m'        # #34D399 — emerald green (clean/secure)
WARN=$'\033[38;2;255;149;0m'          # #FF9500 — warning orange
# UI chrome
DIM=$'\033[38;2;107;99;136m'          # #6B6388 — purple-tinted dim
WHITE=$'\033[38;2;237;233;254m'       # #EDE9FE — lavender white (project name)
SEP="${DIM}│${R}"

# ─── Read Claude session data from stdin ──────────────────────────────────────
SESSION=$(cat)
# Available session fields (for future use):
#   model, contextWindowPercent, sessionCost, gitBranch, worktreeName, vimMode
# Example: MODEL=$(printf '%s' "$SESSION" | jq -r '.model // empty')

# ─── Determine project root ───────────────────────────────────────────────────
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT=$(basename "$GIT_ROOT")

# ─── Cache paths (separate files per scan type) ───────────────────────────────
mkdir -p "$CACHE_DIR"
PATH_HASH=$(printf '%s' "$GIT_ROOT" | cksum | cut -d' ' -f1)

# SCA: snyk test (dependency vulnerabilities)
SCA_CACHE="$CACHE_DIR/${PATH_HASH}.sca.json"
SCA_LOCK="$CACHE_DIR/${PATH_HASH}.sca.lock"
SCA_ERR="$CACHE_DIR/${PATH_HASH}.sca.err"
SCA_NOSCAN="$CACHE_DIR/${PATH_HASH}.sca.noscan"

# SAST: snyk code test (source code security issues)
SAST_CACHE="$CACHE_DIR/${PATH_HASH}.sast.json"
SAST_LOCK="$CACHE_DIR/${PATH_HASH}.sast.lock"
SAST_ERR="$CACHE_DIR/${PATH_HASH}.sast.err"
SAST_NOSCAN="$CACHE_DIR/${PATH_HASH}.sast.noscan"

# ─── Helpers ──────────────────────────────────────────────────────────────────
# Age in seconds of a file (999999 if missing)
file_age() {
    local f="$1"
    [[ -f "$f" ]] || { printf '999999'; return; }
    local mtime
    mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || printf '0')
    printf '%d' $(( $(date +%s) - mtime ))
}

# Age of a scan slot — whichever of cache or noscan sentinel is fresher
scan_age() {
    local cache="$1" noscan="$2"
    local ca na
    ca=$(file_age "$cache")
    na=$(file_age "$noscan")
    (( ca < na )) && printf '%d' "$ca" || printf '%d' "$na"
}

fmt_age() {
    local s=$1
    if   (( s < 60 ));   then printf '%ds' "$s"
    elif (( s < 3600 )); then printf '%dm' "$(( s / 60 ))"
    else                      printf '%dh' "$(( s / 3600 ))"
    fi
}

# ─── Background scan: SCA (snyk test) ────────────────────────────────────────
trigger_sca_bg() {
    mkdir "$SCA_LOCK" 2>/dev/null || return  # already running
    (
        trap 'rm -rf "$SCA_LOCK"' EXIT
        cd "$GIT_ROOT"
        local tmp="$SCA_CACHE.tmp" exit_code=0
        # shellcheck disable=SC2086
        "$SNYK_BIN" test --json $SNYK_SCAN_ARGS > "$tmp" 2>"$SCA_ERR" || exit_code=$?
        if (( exit_code == 3 )); then
            printf '3' > "$SCA_NOSCAN"; rm -f "$tmp"
        elif [[ -s "$tmp" ]] && jq -e '.vulnerabilities' "$tmp" &>/dev/null; then
            rm -f "$SCA_NOSCAN"; mv "$tmp" "$SCA_CACHE"
        else
            rm -f "$tmp"
        fi
    ) &>/dev/null &
    disown
}

# ─── Background scan: SAST (snyk code test) ──────────────────────────────────
trigger_sast_bg() {
    mkdir "$SAST_LOCK" 2>/dev/null || return  # already running
    (
        trap 'rm -rf "$SAST_LOCK"' EXIT
        cd "$GIT_ROOT"
        local tmp="$SAST_CACHE.tmp" exit_code=0
        "$SNYK_BIN" code test --json > "$tmp" 2>"$SAST_ERR" || exit_code=$?
        if (( exit_code == 3 )); then
            printf '3' > "$SAST_NOSCAN"; rm -f "$tmp"
        elif [[ -s "$tmp" ]] && jq -e '.runs[0].results' "$tmp" &>/dev/null; then
            rm -f "$SAST_NOSCAN"; mv "$tmp" "$SAST_CACHE"
        else
            rm -f "$tmp"
        fi
    ) &>/dev/null &
    disown
}

# ─── Trigger stale scans ──────────────────────────────────────────────────────
SCA_AGE=$(scan_age "$SCA_CACHE" "$SCA_NOSCAN")
SAST_AGE=$(scan_age "$SAST_CACHE" "$SAST_NOSCAN")
(( SCA_AGE  > CACHE_TTL )) && trigger_sca_bg
(( SAST_AGE > CACHE_TTL )) && trigger_sast_bg

SCA_SCANNING=$( [[ -d "$SCA_LOCK"  ]] && printf 'true' || printf 'false' )
SAST_SCANNING=$([[ -d "$SAST_LOCK" ]] && printf 'true' || printf 'false' )
SPIN=$( ( $SCA_SCANNING || $SAST_SCANNING ) && printf " ${SNYK}⟳${R}" || printf '' )

# ─── Auth check (shared error files) ─────────────────────────────────────────
is_auth_error() {
    local err_file="$1"
    [[ -s "$err_file" ]] && grep -qi 'auth\|token\|login\|authenticate' "$err_file" 2>/dev/null
}

if is_auth_error "$SCA_ERR" || is_auth_error "$SAST_ERR"; then
    if [[ ! -f "$SCA_CACHE" ]] && [[ ! -f "$SAST_CACHE" ]]; then
        printf '%s⬡ snyk%s %s %s⚠ auth required%s  run: snyk auth\n' \
            "$SNYK" "$R" "$SEP" "$WARN" "$R"
        exit 0
    fi
fi

# ─── Build SCA segment ────────────────────────────────────────────────────────
build_sca_segment() {
    if $SCA_SCANNING && [[ ! -f "$SCA_CACHE" ]]; then
        printf '%sdeps scanning...%s' "$DIM" "$R"; return
    fi
    if [[ -f "$SCA_NOSCAN" ]] && [[ ! -f "$SCA_CACHE" ]]; then
        printf '%sno deps to scan%s' "$DIM" "$R"; return
    fi
    if [[ ! -f "$SCA_CACHE" ]]; then
        printf '%sdeps initializing...%s' "$DIM" "$R"; return
    fi

    IFS='|' read -r OK TOTAL C H M L FIXABLE < <(
        jq -r '[
            (.ok // false | tostring),
            (.uniqueCount // 0 | tostring),
            ([.vulnerabilities[]? | select(.severity == "critical")] | length | tostring),
            ([.vulnerabilities[]? | select(.severity == "high")]     | length | tostring),
            ([.vulnerabilities[]? | select(.severity == "medium")]   | length | tostring),
            ([.vulnerabilities[]? | select(.severity == "low")]      | length | tostring),
            ([.vulnerabilities[]? | select(.isUpgradable == true or .isPatchable == true)] | length | tostring)
        ] | join("|")' "$SCA_CACHE" 2>/dev/null || printf 'false|0|0|0|0|0|0'
    )

    if [[ "$OK" == "true" ]] || (( TOTAL == 0 )); then
        printf '%sdeps%s %s✦%s' "$DIM" "$R" "$CLEAN" "$R"
        return
    fi

    local sev=""
    (( C > 0 )) && sev+="${CRIT}● C:${C}${R} "
    (( H > 0 )) && sev+="${HIGH}● H:${H}${R} "
    (( M > 0 )) && sev+="${MED}● M:${M}${R} "
    [[ "$SHOW_LOW" == "true" ]] && (( L > 0 )) && sev+="${LOW}● L:${L}${R} "
    sev="${sev% }"

    printf '%sdeps%s %s' "$DIM" "$R" "$sev"
    (( FIXABLE > 0 )) && printf ' %s↑%d%s' "$DIM" "$FIXABLE" "$R"
}

# ─── Build SAST segment ───────────────────────────────────────────────────────
# SARIF severity mapping: error → high, warning → medium, note → low
build_sast_segment() {
    if $SAST_SCANNING && [[ ! -f "$SAST_CACHE" ]]; then
        printf '%scode scanning...%s' "$DIM" "$R"; return
    fi
    if [[ -f "$SAST_NOSCAN" ]] && [[ ! -f "$SAST_CACHE" ]]; then
        printf '%sno code to scan%s' "$DIM" "$R"; return
    fi
    if [[ ! -f "$SAST_CACHE" ]]; then
        printf '%scode initializing...%s' "$DIM" "$R"; return
    fi

    IFS='|' read -r TOTAL H M L FIXABLE < <(
        jq -r '[
            (.runs[0].results | length | tostring),
            ([.runs[0].results[]? | select(.level == "error")]   | length | tostring),
            ([.runs[0].results[]? | select(.level == "warning")] | length | tostring),
            ([.runs[0].results[]? | select(.level == "note")]    | length | tostring),
            ([.runs[0].results[]? | select(.properties.isAutofixable == true)] | length | tostring)
        ] | join("|")' "$SAST_CACHE" 2>/dev/null || printf '0|0|0|0|0'
    )

    if (( TOTAL == 0 )); then
        printf '%scode%s %s✦%s' "$DIM" "$R" "$CLEAN" "$R"
        return
    fi

    local sev=""
    (( H > 0 )) && sev+="${HIGH}● H:${H}${R} "
    (( M > 0 )) && sev+="${MED}● M:${M}${R} "
    [[ "$SHOW_LOW" == "true" ]] && (( L > 0 )) && sev+="${LOW}● L:${L}${R} "
    sev="${sev% }"

    printf '%scode%s %s' "$DIM" "$R" "$sev"
    (( FIXABLE > 0 )) && printf ' %s↑%d%s' "$DIM" "$FIXABLE" "$R"
}

# ─── Compose final output ─────────────────────────────────────────────────────
SCA_SEG=$(build_sca_segment)
SAST_SEG=$(build_sast_segment)

# Show age of the oldest completed scan (most conservative freshness indicator)
OLDEST_AGE=$(( SCA_AGE > SAST_AGE ? SCA_AGE : SAST_AGE ))
if (( OLDEST_AGE < 999999 )); then
    AGE_STR=" ${DIM}· $(fmt_age "$OLDEST_AGE")${R}"
else
    AGE_STR=""
fi

printf '%s⬡ snyk%s %s %s %s %s %s %s%s%s\n' \
    "$SNYK" "$R" \
    "$SEP" "$SCA_SEG" \
    "$SEP" "$SAST_SEG" \
    "$SEP" "${WHITE}${PROJECT}${R}" "$AGE_STR" "$SPIN"
