#!/usr/bin/env bash
#
# vldo.sh — download every URL in a file with yt-dlp, one at a time,
# removing each URL from the list as it succeeds and logging failures.
#
# Usage: batch_download.sh <file_list> [max_height]

set -u

# ── Colors ────────────────────────────────────────────────────────────────
readonly C_RED='\033[1;31m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[1;34m'
readonly C_CYAN='\033[1;36m'
readonly C_RESET='\033[0m'

readonly OUTPUT_DIR="."
readonly FAILED_LOG="failed.txt"
readonly DEFAULT_HEIGHT=250

# ── Graceful exit on Ctrl+C ─────────────────────────────────────────────────
trap 'echo -e "\n${C_RED}⚠ Download interrupted by user${C_RESET}"; exit 130' INT

# ── Helpers ──────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 <file_list> [max_height]"
    exit 1
}

# Escape a string for safe use inside a sed basic-regex pattern.
escape_for_sed() {
    printf '%s\n' "$1" | sed 's/[.[\*^$/]/\\&/g'
}

# Remove the first line containing $1 (exact URL) from $2 (file).
remove_url() {
    local url="$1" file="$2"
    local pattern
    pattern=$(escape_for_sed "$url")
    sed -i "\\|$pattern|d" "$file"
}

log_failed_url() {
    local url="$1"
    mkdir -p "$(dirname "$FAILED_LOG")"
    printf '%s\n' "$url" >> "$FAILED_LOG"
}

download_one() {
    local url="$1" height="$2"

    echo "🎬 Downloading: $url"

    if yt-dlp -c \
        -f "[height<=${height}]+[height<=${height}]" \
        -P "$OUTPUT_DIR" \
        --progress \
        --quiet \
        --no-warnings \
        --progress-template $'\033[1;34mDownloading\033[0m %(progress._percent_str)s %(progress._total_bytes_estimate_str)s  %(progress._speed_str)s  %(progress._eta_str)s' \
        "$url"
    then
        remove_url "$url" "$file_list"
        echo -e "\n${C_GREEN}✔ Download Complete${C_RESET}\n"
    else
        log_failed_url "$url"
        remove_url "$url" "$file_list"
        echo -e "${C_YELLOW}⚠ Failed - Moving to failed log${C_RESET}"
    fi
}

run_queue() {
    local height="$1"

    while grep -q "http" "$file_list"; do
        local url
        url=$(grep "http" "$file_list" | head -n 1)
        [ -z "$url" ] && continue
        download_one "$url" "$height"
    done

    echo
    echo -e "${C_CYAN}[+] All matching links processed!${C_RESET}"
}

# ── Main ─────────────────────────────────────────────────────────────────
[ -z "${1:-}" ] && usage

file_list="$1"

if [ ! -f "$file_list" ]; then
    echo -e "${C_RED} Error: File '$file_list' not found${C_RESET}"
    exit 1
fi

height="${2:-$DEFAULT_HEIGHT}"
run_queue "$height"
