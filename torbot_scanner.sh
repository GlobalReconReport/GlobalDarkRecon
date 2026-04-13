#!/bin/bash
TORBOT_DIR="/opt/TorBot"
source "$TORBOT_DIR/venv/bin/activate"
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
log() {
    local msg="[$(date +"%H:%M:%S")] $1"
    echo -e "$msg"
    echo "$msg" >> "$LOG_FILE"
}
check_tor() {
    if ss -tlnp | grep -q ":9050"; then
        log "${GREEN}[+] Tor SOCKS proxy is running on port 9050${NC}"
        return 0
    else
        log "${RED}[-] Tor SOCKS proxy not detected on port 9050${NC}"
        sudo systemctl start tor@default
        sleep 3
        if ss -tlnp | grep -q ":9050"; then
            log "${GREEN}[+] Tor started successfully${NC}"
            return 0
        else
            log "${RED}[-] Failed to start Tor. Exiting.${NC}"
            return 1
        fi
    fi
}
scan_target() {
    local url="$1"
    local index="$2"
    local total="$3"
    local safe_name=$(echo "$url" | sed 's|https\?://||' | sed 's|[^a-zA-Z0-9]|_|g' | cut -c1-60)
    local output_dir="$RESULTS_DIR/$safe_name"
    mkdir -p "$output_dir"
    log "${CYAN}[${index}/${total}] Scanning: ${url}${NC}"
    cd "$TORBOT_DIR"
    PYTHONPATH=src timeout 300 python3 main.py -u "$url" --depth "$DEPTH" --save json --visualize table > "$output_dir/stdout.txt" 2>"$output_dir/stderr.txt"
    local exit_code=$?
    if ls "$TORBOT_DIR"/*.json 1>/dev/null 2>&1; then
        mv "$TORBOT_DIR"/*.json "$output_dir/" 2>/dev/null
    fi
    if [ $exit_code -eq 0 ]; then
        log "${GREEN}  [+] Success${NC}"
        echo "SUCCESS | $url" >> "$SUMMARY_FILE"
    elif [ $exit_code -eq 124 ]; then
        log "${YELLOW}  [!] Timeout after 120s${NC}"
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
if [ ! -f "$TARGETS_FILE" ]; then
    cat > "$HOME/onion_targets.txt" << 'EOF'
# TorBot Scanner Targets
https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion
EOF
    echo -e "${GREEN}[+] Sample targets file created. Edit ~/onion_targets.txt then run again.${NC}"
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
    log "${RED}[-] No targets found${NC}"
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
