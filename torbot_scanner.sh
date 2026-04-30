#!/bin/bash
set -eo pipefail

TORBOT_DIR="/opt/TorBot"
PYTHON="$TORBOT_DIR/venv/bin/python3"
TARGETS_FILE="${1:-$HOME/onion_targets.txt}"
DEPTH="${2:-2}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="$HOME/torbot_results/$TIMESTAMP"
LOG_FILE="$RESULTS_DIR/scan_log.txt"
SUMMARY_FILE="$RESULTS_DIR/summary.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Strip ANSI codes when writing to log file so it stays grep-friendly
log() {
    local msg="[$(date +"%H:%M:%S")] $1"
    echo -e "$msg"
    echo "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
}

check_tor() {
    if ss -tlnp | grep -q ":9050"; then
        log "${GREEN}[+] Tor SOCKS proxy is running on port 9050${NC}"
        return 0
    else
        log "${RED}[-] Tor SOCKS proxy not detected on port 9050${NC}"
        # Avoid sudo prompt in non-interactive runs; try both unit names
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

scan_target() {
    local url="$1"
    local index="$2"
    local total="$3"
    local safe_name
    safe_name=$(echo "$url" | sed 's|https\?://||' | sed 's|[^a-zA-Z0-9]|_|g' | cut -c1-60)
    local output_dir="$RESULTS_DIR/$safe_name"
    mkdir -p "$output_dir"
    log "${CYAN}[${index}/${total}] Scanning: ${url}${NC}"

    # Run TorBot in a subshell so the cd doesn't affect the parent shell's cwd
    (
        cd "$TORBOT_DIR"
        PYTHONPATH="$TORBOT_DIR/src" timeout 300 "$PYTHON" main.py \
            -u "$url" --depth "$DEPTH" --save json --visualize table \
            > "$output_dir/stdout.txt" 2>"$output_dir/stderr.txt"
    )
    local exit_code=$?

    # Move any JSON output TorBot wrote to $TORBOT_DIR into the result dir
    if ls "$TORBOT_DIR"/*.json 1>/dev/null 2>&1; then
        mv "$TORBOT_DIR"/*.json "$output_dir/" 2>/dev/null || true
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
if [ ! -f "$TARGETS_FILE" ]; then
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
log "  Targets file : $TARGETS_FILE"
log "  Crawl depth  : $DEPTH"
log "  Results dir  : $RESULTS_DIR"

echo "-------------------------------------------" >> "$SUMMARY_FILE"
echo "Scan started: $(date)" >> "$SUMMARY_FILE"
echo "-------------------------------------------" >> "$SUMMARY_FILE"

check_tor || exit 1

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
