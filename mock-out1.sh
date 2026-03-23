#!/usr/bin/env bash
# Mock: severity letter gets vivid color background + white text
# Compare current style vs proposed style

R=$'\033[0m'
# Letter color options to compare
OPT_A=$'\033[38;2;255;255;255m'   # A: pure white
OPT_B=$'\033[38;2;30;15;10m'      # B: near-black (warm dark)
OPT_C=$'\033[38;2;255;220;180m'   # C: warm cream (light tint of the hue)
OPT_D=$'\033[38;2;80;40;10m'      # D: dark brown (hue-matched dark)
SNYK=$'\033[38;2;168;85;247m'
DIM=$'\033[38;2;107;99;136m'
SEP="${DIM}│${R}"

# Vivid label colors (current letter fg → becomes letter bg in new style)
CRIT=$'\033[38;2;255;59;48m'
HIGH=$'\033[38;2;255;149;0m'
MED=$'\033[38;2;255;204;0m'
LOW=$'\033[38;2;152;152;168m'

# Badge count colors (muted text inside dark bg)
CRIT_C=$'\033[38;2;200;80;70m'
HIGH_C=$'\033[38;2;200;130;50m'
MED_C=$'\033[38;2;185;158;0m'
LOW_C=$'\033[38;2;112;110;130m'

# Badge backgrounds (dark-tinted)
CRIT_BG=$'\033[48;2;75;12;10m'
HIGH_BG=$'\033[48;2;65;35;0m'
MED_BG=$'\033[48;2;62;50;0m'
LOW_BG=$'\033[48;2;42;40;52m'

# NEW: vivid backgrounds for the letter (RGB from the vivid fg colors)
CRIT_LBG=$'\033[48;2;255;59;48m'
HIGH_LBG=$'\033[48;2;255;149;0m'
MED_LBG=$'\033[48;2;255;204;0m'
LOW_LBG=$'\033[48;2;152;152;168m'

CLEAN=$'\033[38;2;52;211;153m'
PROJ=$'\033[38;2;237;233;254m'

# Current style: count on dark bg, letter in vivid fg, no bg
badge_current() {
    local count="$1" letter="$2" bg="$3" num_fg="$4" label_fg="$5"
    printf '%s%s %d %s%s%s%s' "$bg" "$num_fg" "$count" "$R" "$label_fg" "$letter" "$R"
}

# Proposed style: count on dark bg, letter on vivid bg with configurable text color
badge_new() {
    local count="$1" letter="$2" bg="$3" num_fg="$4" label_bg="$5" letter_fg="$6"
    printf '%s%s %d %s%s%s%s%s' "$bg" "$num_fg" "$count" "$R" "$label_bg" "$letter_fg" "$letter" "$R"
}

row() {
    local label="$1" letter_fg="$2"
    printf '  %s⬡ snyk%s %s %sdeps%s ' "$SNYK" "$R" "$SEP" "$DIM" "$R"
    printf '%s ' "$(badge_new 2 C "$CRIT_BG" "$CRIT_C" "$CRIT_LBG" "$letter_fg")"
    printf '%s ' "$(badge_new 4 H "$HIGH_BG" "$HIGH_C" "$HIGH_LBG" "$letter_fg")"
    printf '%s'  "$(badge_new 2 M "$MED_BG"  "$MED_C"  "$MED_LBG"  "$letter_fg")"
    printf ' %s↑6%s %s %sdeps%s %s✦%s %s %s%snodejs-goof%s %s· 5m%s' \
        "$DIM" "$R" "$SEP" "$DIM" "$R" "$CLEAN" "$R" "$SEP" "$PROJ" "$R" "$R" "$DIM" "$R"
    printf '   %s← %s%s\n' "$DIM" "$label" "$R"
}

printf '\n'
row "current (original style, no badge bg)" "$CRIT"  # reuse as placeholder, shown separately

printf '\n  %sCURRENT (original)%s\n' "$DIM" "$R"
printf '  %s⬡ snyk%s %s %sdeps%s ' "$SNYK" "$R" "$SEP" "$DIM" "$R"
printf '%s ' "$(badge_current 2 C "$CRIT_BG" "$CRIT_C" "$CRIT")"
printf '%s ' "$(badge_current 4 H "$HIGH_BG" "$HIGH_C" "$HIGH")"
printf '%s'  "$(badge_current 2 M "$MED_BG"  "$MED_C"  "$MED")"
printf ' %s↑6%s %s %sdeps%s %s✦%s %s %s%snodejs-goof%s %s· 5m%s\n' \
    "$DIM" "$R" "$SEP" "$DIM" "$R" "$CLEAN" "$R" "$SEP" "$PROJ" "$R" "$R" "$DIM" "$R"

printf '\n  %sPROPOSED — letter color options%s\n\n' "$DIM" "$R"
row "A: pure white  #FFFFFF" "$OPT_A"
row "B: near-black  #1E0F0A" "$OPT_B"
row "C: warm cream  #FFDCB4" "$OPT_C"
row "D: dark brown  #50280A" "$OPT_D"
printf '\n'
