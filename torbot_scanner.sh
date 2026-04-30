#!/bin/bash
set -eo pipefail

TORBOT_DIR="/opt/TorBot"
PYTHON="$TORBOT_DIR/venv/bin/python3"
SCRIPT_DIR="/opt/GlobalDarkRecon"
FIREJAIL_PROFILE="$SCRIPT_DIR/torbot.profile"
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
