#!/bin/bash
set -eo pipefail

TORBOT_DIR="/opt/TorBot"
PYTHON="$TORBOT_DIR/venv/bin/python3"
SCRIPT_DIR="/opt/GlobalDarkRecon"
FIREJAIL_PROFILE="$SCRIPT_DIR/torbot.profile"
SEARCH_KEYWORD=""
SEARCH_ENGINE=""
DIRECT_URL=""
TARGETS_FILE=""
DEPTH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --search) SEARCH_KEYWORD="$2"; shift 2 ;;
        --engine) SEARCH_ENGINE="$2"; shift 2 ;;
        http://*|https://*) DIRECT_URL="$1"; shift ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                DEPTH="$1"
            else
                TARGETS_FILE="$1"
            fi
            shift ;;
    esac
done
DEPTH="${DEPTH:-2}"

if [ -n "$DIRECT_URL" ]; then
    TARGETS_FILE=$(mktemp /tmp/darkrecon_target.XXXXXX)
    echo "$DIRECT_URL" > "$TARGETS_FILE"
    trap 'rm -f "$TARGETS_FILE"' EXIT
elif [ -z "$SEARCH_KEYWORD" ]; then
    TARGETS_FILE="${TARGETS_FILE:-$HOME/onion_targets.txt}"
fi
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="$HOME/torbot_results/$TIMESTAMP"
LOG_FILE="$RESULTS_DIR/scan_log.txt"
SUMMARY_FILE="$RESULTS_DIR/summary.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Strip ANSI codes when writing to log file so it stays grep-friendly.
# Color vars use literal \033 (single-quoted), so echo -e must expand them
# before sed can match the resulting ESC (0x1b) bytes.
log() {
    local msg="[$(date +"%H:%M:%S")] $1"
    echo -e "$msg"
    echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
}

check_tor() {
    if ss -tlnp | grep -q ":9050"; then
        log "${GREEN}[+] Tor SOCKS proxy is running on port 9050${NC}"
        return 0
    else
        log "${RED}[-] Tor SOCKS proxy not detected on port 9050${NC}"
        systemctl start tor 2>/dev/null || systemctl start tor@default 2>/dev/null || true
        sleep 3
        if ss -tlnp | grep -q ":9050"; then
            log "${GREEN}[+] Tor started successfully${NC}"
            return 0
        else
            log "${RED}[-] Failed to start Tor. Run: sudo systemctl start tor${NC}"
            return 1
        fi
    fi
}

sandbox_active() {
    command -v firejail &>/dev/null && [ -f "$FIREJAIL_PROFILE" ]
}

scan_target() {
    local url="$1"
    local index="$2"
    local total="$3"
    local safe_name
    safe_name=$(echo "$url" | sed 's|https\?://||' | sed 's|[^a-zA-Z0-9]|_|g' | cut -c1-60)
    local output_dir="$RESULTS_DIR/$safe_name"
    mkdir -p "$output_dir"
    log "${CYAN}[${index}/${total}] Scanning: ${url}${NC}"

    # Capture exit code without triggering set -e on non-zero exit
    local exit_code=0
    if sandbox_active; then
        # Firejail mode: TorBot dir is read-only so --save json is omitted
        # (TorBot writes JSON to its own src/ dir which would fail read-only).
        # All intelligence is captured in stdout.txt via --visualize table.
        (
            cd "$TORBOT_DIR"
            timeout 300 firejail \
                --profile="$FIREJAIL_PROFILE" \
                --read-only="$TORBOT_DIR" \
                --env="PYTHONPATH=$TORBOT_DIR/src" \
                -- \
                "$PYTHON" main.py \
                    -u "$url" --depth "$DEPTH" --visualize table \
                    > "$output_dir/stdout.txt" 2>"$output_dir/stderr.txt"
        ) || exit_code=$?
    else
        (
            cd "$TORBOT_DIR"
            PYTHONPATH="$TORBOT_DIR/src" timeout 300 "$PYTHON" main.py \
                -u "$url" --depth "$DEPTH" --save json --visualize table \
                > "$output_dir/stdout.txt" 2>"$output_dir/stderr.txt"
        ) || exit_code=$?
        # TorBot writes JSON to src/ (project_root_directory in config.py)
        if ls "$TORBOT_DIR"/src/*.json 1>/dev/null 2>&1; then
            mv "$TORBOT_DIR"/src/*.json "$output_dir/" 2>/dev/null || true
        fi
    fi

    if [ "$exit_code" -eq 0 ]; then
        log "${GREEN}  [+] Success${NC}"
        echo "SUCCESS | $url" >> "$SUMMARY_FILE"
    elif [ "$exit_code" -eq 124 ]; then
        log "${YELLOW}  [!] Timeout after 300s${NC}"
        echo "TIMEOUT | $url" >> "$SUMMARY_FILE"
    else
        log "${RED}  [-] Failed (exit code: $exit_code)${NC}"
        echo "FAILED  | $url" >> "$SUMMARY_FILE"
    fi
    sleep 5
}

echo -e "${RED}"
echo ' ██████╗ ██╗      ██████╗ ██████╗  █████╗ ██╗     '
echo ' ██╔════╝ ██║     ██╔═══██╗██╔══██╗██╔══██╗██║     '
echo ' ██║  ███╗██║     ██║   ██║██████╔╝███████║██║     '
echo ' ██║   ██║██║     ██║   ██║██╔══██╗██╔══██║██║     '
echo ' ╚██████╔╝███████╗╚██████╔╝██████╔╝██║  ██║███████╗'
echo '  ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝'
echo -e "${NC}"
echo -e "${CYAN} ██████╗  █████╗ ██████╗ ██╗  ██╗██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗${NC}"
echo -e "${CYAN} ██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║${NC}"
echo -e "${CYAN} ██║  ██║███████║██████╔╝█████╔╝ ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║${NC}"
echo -e "${CYAN} ██║  ██║██╔══██║██╔══██╗██╔═██╗ ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║${NC}"
echo -e "${CYAN} ██████╔╝██║  ██║██║  ██║██║  ██╗██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║${NC}"
echo -e "${CYAN} ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝${NC}"
echo -e "${RED}  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${NC}"
echo -e "${YELLOW}              ⚡ Dark Web OSINT Intelligence Platform ⚡  ${NC}"
echo -e "${RED}  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀${NC}"

# Create targets file if missing, then exit so the user can edit it
if [ -z "$SEARCH_KEYWORD" ] && [ -z "$DIRECT_URL" ] && [ ! -f "$TARGETS_FILE" ]; then
    cat > "$TARGETS_FILE" << 'EOF'
# TorBot Scanner Targets
https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion
EOF
    echo -e "${GREEN}[+] Sample targets file created at $TARGETS_FILE. Edit it then run again.${NC}"
    exit 0
fi

mkdir -p "$RESULTS_DIR"
touch "$LOG_FILE" "$SUMMARY_FILE"

log "${GREEN}[+] TorBot Multi-Target Scanner${NC}"
if [ -n "$SEARCH_KEYWORD" ]; then
    log "  Mode         : keyword search"
    log "  Keyword      : $SEARCH_KEYWORD"
    log "  Engine       : $SEARCH_ENGINE"
elif [ -n "$DIRECT_URL" ]; then
    log "  URL          : $DIRECT_URL"
else
    log "  Targets file : $TARGETS_FILE"
fi
log "  Crawl depth  : $DEPTH"
log "  Results dir  : $RESULTS_DIR"

# Report sandbox status before any scanning begins
if sandbox_active; then
    log "${GREEN}[+] Firejail sandbox : ACTIVE${NC}"
    log "  Profile      : $FIREJAIL_PROFILE"
    log "  Isolation    : caps.drop=all | seccomp | protocol=inet | filesystem blacklists"
else
    log "${YELLOW}[!] Firejail sandbox : INACTIVE${NC}"
    if ! command -v firejail &>/dev/null; then
        log "    Install firejail for sandboxed scans: sudo apt-get install -y firejail"
    fi
fi

echo "-------------------------------------------" >> "$SUMMARY_FILE"
echo "Scan started: $(date)" >> "$SUMMARY_FILE"
echo "-------------------------------------------" >> "$SUMMARY_FILE"

check_tor || exit 1

# ── Search mode: fetch results page and discover onion targets ────────────────
if [ -n "$SEARCH_KEYWORD" ]; then
    if [ -z "$SEARCH_ENGINE" ]; then
        log "${RED}[-] --search requires --engine <onion_url>${NC}"; exit 1
    fi
    ENCODED_KEYWORD=$("$PYTHON" -c \
        "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" \
        "$SEARCH_KEYWORD")
    if [[ "$SEARCH_ENGINE" == *"?"* ]]; then
        SEARCH_URL="${SEARCH_ENGINE%/}&q=${ENCODED_KEYWORD}"
    else
        SEARCH_URL="${SEARCH_ENGINE%/}?q=${ENCODED_KEYWORD}"
    fi
    log "${CYAN}[*] Fetching search results through Tor...${NC}"
    log "  Query URL : $SEARCH_URL"
    DISCOVERED_FILE="$RESULTS_DIR/discovered_links.txt"
    fetch_exit=0
    curl --socks5-hostname 127.0.0.1:9050 \
         --max-time 60 --silent --location \
         --user-agent "Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101 Firefox/115.0" \
         "$SEARCH_URL" 2>/dev/null \
    | "$PYTHON" -c "
import sys, re, html as _h
page = sys.stdin.read()
raw = re.findall(r'https?://[a-z2-7]{16,56}\.onion(?:[/?#][^\s<>\"\']*)?', page, re.I)
cleaned = [_h.unescape(u).rstrip('.,;:)') for u in raw]
urls = sorted(set(cleaned))
for u in urls: print(u)
" > "$DISCOVERED_FILE" || fetch_exit=$?
    if [ "$fetch_exit" -ne 0 ] || [ ! -s "$DISCOVERED_FILE" ]; then
        log "${RED}[-] No onion links discovered. Check keyword, engine URL, and Tor connectivity.${NC}"
        exit 1
    fi
    DISC_COUNT=$(wc -l < "$DISCOVERED_FILE")
    log "${GREEN}[+] Discovered $DISC_COUNT onion link(s)${NC}"
    while IFS= read -r link; do
        log "  ${CYAN}→${NC} $link"
    done < "$DISCOVERED_FILE"
    TARGETS_FILE="$DISCOVERED_FILE"
fi

mapfile -t TARGETS < <(grep -v '^\s*#' "$TARGETS_FILE" | grep -v '^\s*$')
TOTAL=${#TARGETS[@]}

if [ "$TOTAL" -eq 0 ]; then
    log "${RED}[-] No targets found in $TARGETS_FILE${NC}"
    exit 1
fi

log "${GREEN}[+] Loaded $TOTAL target(s)${NC}"

for i in "${!TARGETS[@]}"; do
    scan_target "${TARGETS[$i]}" "$((i + 1))" "$TOTAL"
done

echo "-------------------------------------------" >> "$SUMMARY_FILE"
echo "Scan completed: $(date)" >> "$SUMMARY_FILE"

log "${GREEN}[+] Scan complete!${NC}"
log "  Results : $RESULTS_DIR"

echo -e "${CYAN}--- Summary ---${NC}"
cat "$SUMMARY_FILE"
