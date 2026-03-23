#!/usr/bin/env bash
# =============================================================================
# Snyk Security Statusline — Installer
# =============================================================================
# Registers the statusline script with Claude Code by updating
# ~/.claude/settings.json.
#
# Usage:
#   ./install.sh           Install (uses absolute path to statusline.sh)
#   ./install.sh --remove  Remove the statusline from settings
# =============================================================================

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/statusline.sh"
REMOVE="${1:-}"

# ─── Colors ──────────────────────────────────────────────────────────────────
R=$'\033[0m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
BOLD=$'\033[1m'

ok()   { printf '%s✔%s  %s\n' "$GREEN" "$R" "$1"; }
info() { printf '%sℹ%s  %s\n' "$YELLOW" "$R" "$1"; }
err()  { printf '%s✘%s  %s\n' "$RED" "$R" "$1"; }

# ─── Preflight checks ─────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    command -v jq    &>/dev/null || missing+=("jq")
    command -v snyk  &>/dev/null || missing+=("snyk")

    if (( ${#missing[@]} > 0 )); then
        err "Missing required tools: ${missing[*]}"
        printf '\n  Install them with:\n'
        [[ " ${missing[*]} " == *" jq "* ]]   && printf '    • jq:   apt install jq  /  brew install jq\n'
        [[ " ${missing[*]} " == *" snyk "* ]] && printf '    • snyk: npm install -g snyk\n'
        exit 1
    fi
}

# ─── Remove mode ──────────────────────────────────────────────────────────────
if [[ "$REMOVE" == "--remove" ]]; then
    if [[ ! -f "$SETTINGS" ]]; then
        info "No settings file found at $SETTINGS — nothing to remove."
        exit 0
    fi
    jq 'del(.statusLine)' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    ok "Removed statusLine from $SETTINGS"
    info "Restart Claude Code for the change to take effect."
    exit 0
fi

# ─── Install mode ─────────────────────────────────────────────────────────────
printf '\n%sSnyk Security Statusline — Installer%s\n\n' "$BOLD" "$R"

check_deps

# Make script executable
chmod +x "$SCRIPT_PATH"
ok "Made $SCRIPT_PATH executable"

# Check snyk auth
if ! snyk whoami --experimental &>/dev/null; then
    info "Snyk is not authenticated. Run ${BOLD}snyk auth${R} to complete the OAuth flow."
    info "Once authenticated, verify with: ${BOLD}snyk whoami --experimental${R}"
    info "The statusline will show an auth warning until you authenticate."
fi

# Create or update settings.json
if [[ ! -f "$SETTINGS" ]]; then
    mkdir -p "$(dirname "$SETTINGS")"
    jq -n --arg path "$SCRIPT_PATH" '{"statusLine": {"type": "command", "command": $path}}' > "$SETTINGS"
    ok "Created $SETTINGS with statusLine"
else
    # Preserve existing settings, just update/add statusLine
    jq --arg path "$SCRIPT_PATH" '.statusLine = {"type": "command", "command": $path}' "$SETTINGS" > "$SETTINGS.tmp" \
        && mv "$SETTINGS.tmp" "$SETTINGS"
    ok "Updated $SETTINGS with statusLine"
fi

printf '\n%sDone!%s The statusline will appear next time Claude Code starts a session.\n\n' "$GREEN" "$R"
printf 'statusLine path: %s\n\n' "$SCRIPT_PATH"
printf 'Optional: configure with environment variables:\n'
printf '  SNYK_STATUSLINE_TTL   Seconds between scans (default: 300)\n'
printf '  SNYK_SHOW_LOW         Show low severity issues (default: false)\n'
printf '  SNYK_SCAN_ARGS        Extra args passed to snyk test\n'
printf '  SNYK_BIN              Path to snyk binary (default: snyk)\n\n'
