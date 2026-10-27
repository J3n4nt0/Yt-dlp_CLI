#!/usr/bin/env bash
#
# yt-dlp_CLI.sh — download every URL in a file with yt-dlp, one at a time,
# removing each URL from the list as it succeeds and logging failures.
#
# Usage:
#   yt-dlp_CLI.sh --list <file> [--quality <max_height>] [--output <dir>]
#
# Examples:
#   yt-dlp_CLI.sh --list urls.txt
#   yt-dlp_CLI.sh --list urls.txt --quality 480
#   yt-dlp_CLI.sh --list urls.txt --quality 720 --output ~/Movies

set -u

# ── Colors ────────────────────────────────────────────────────────────────
readonly C_RED='\033[1;31m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[1;34m'
readonly C_CYAN='\033[1;36m'
readonly C_BOLD='\033[1m'
readonly C_RESET='\033[0m'

# ── Symbols (no emoji) ───────────────────────────────────────────────────
readonly SYM_OK="✔"
readonly SYM_FAIL="✘"
readonly SYM_WARN="⚠"
readonly SYM_ARROW="➤"
readonly SYM_DONE="■"

# ── Defaults ─────────────────────────────────────────────────────────────
readonly DEFAULT_HEIGHT=250
readonly DEFAULT_OUTPUT_DIR="/sdcard/.Movie/"
readonly FAILED_LOG="$HOME/bash/p/list/failed.txt"

file_list=""
quality="$DEFAULT_HEIGHT"
output_dir="$DEFAULT_OUTPUT_DIR"

# ── Graceful exit on Ctrl+C ─────────────────────────────────────────────────
trap 'echo -e "\n${C_RED}${SYM_WARN} Download interrupted by user${C_RESET}"; exit 130' INT

# ── Helpers ──────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $0 --list <file_list> [--quality <max_height>] [--output <dir>]

Options:
  --list, -l      Path to the file containing URLs (required)
  --quality, -q   Max video height, e.g. 480, 720, 1080 (default: ${DEFAULT_HEIGHT})
  --output, -o    Output directory passed to yt-dlp (default: ${DEFAULT_OUTPUT_DIR})
  --help, -h      Show this help message
EOF
    exit 1
}

die() {
    echo -e "${C_RED}${SYM_FAIL} $*${C_RESET}"
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

remaining_count() {
    grep -c "http" "$file_list" 2>/dev/null || echo 0
}

download_one() {
    local url="$1" height="$2" index="$3" total="$4"

    echo -e "${C_BLUE}${SYM_ARROW}${C_RESET} ${C_BOLD}[${index}/${total}]${C_RESET} ${url}"

    if yt-dlp -c \
        -f "[height<=${height}]+[height<=${height}]" \
        -P "$output_dir" \
        --progress \
        --quiet \
        --no-warnings \
        --progress-template $'\033[1;34m  \xe2\x80\xba\033[0m %(progress._percent_str)s  %(progress._total_bytes_estimate_str)s  %(progress._speed_str)s  ETA %(progress._eta_str)s' \
        "$url"
    then
        remove_url "$url" "$file_list"
        echo -e "  ${C_GREEN}${SYM_OK} Done${C_RESET}\n"
        return 0
    else
        log_failed_url "$url"
        remove_url "$url" "$file_list"
        echo -e "  ${C_YELLOW}${SYM_WARN} Failed — logged to ${FAILED_LOG}${C_RESET}\n"
        return 1
    fi
}

run_queue() {
    local height="$1"
    local total ok=0 fail=0 index=0

    total=$(remaining_count)
    [ "$total" -eq 0 ] && { echo -e "${C_YELLOW}${SYM_WARN} No links found in '${file_list}'${C_RESET}"; return; }

    echo -e "${C_CYAN}${SYM_ARROW} ${total} link(s) queued — quality <= ${height}p — output: ${output_dir}${C_RESET}\n"

    while grep -q "http" "$file_list"; do
        local url
        url=$(grep "http" "$file_list" | head -n 1)
        [ -z "$url" ] && continue

        index=$((index + 1))
        if download_one "$url" "$height" "$index" "$total"; then
            ok=$((ok + 1))
        else
            fail=$((fail + 1))
        fi
    done

    echo -e "${C_CYAN}${SYM_DONE} All links processed — ${C_GREEN}${ok} succeeded${C_RESET}${C_CYAN}, ${C_YELLOW}${fail} failed${C_RESET}"
}

# ── Argument parsing ─────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
    case "$1" in
        --list|-l)
            file_list="${2:-}"
            shift 2
            ;;
        --quality|-q)
            quality="${2:-}"
            shift 2
            ;;
        --output|-o)
            output_dir="${2:-}"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

# ── Validation ───────────────────────────────────────────────────────────
[ -z "$file_list" ] && usage
[ -f "$file_list" ] || die "File '$file_list' not found"

case "$quality" in
    ''|*[!0-9]*) die "Invalid --quality value: '$quality' (must be a number)" ;;
esac

mkdir -p "$output_dir" 2>/dev/null || die "Cannot create/access output directory: '$output_dir'"

# ── Main ─────────────────────────────────────────────────────────────────
run_queue "$quality"
