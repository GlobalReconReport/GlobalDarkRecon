#!/bin/bash
# GlobalDarkRecon — Installer
# https://github.com/GlobalReconReport/GlobalDarkRecon

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[-]${NC} $1"; exit 1; }

echo -e "${RED}"
echo ' ██████╗ ██╗      ██████╗ ██████╗  █████╗ ██╗     '
echo ' ██╔════╝ ██║     ██╔═══██╗██╔══██╗██╔══██╗██║     '
echo ' ██║  ███╗██║     ██║   ██║██████╔╝███████║██║     '
echo ' ██║   ██║██║     ██║   ██║██╔══██╗██╔══██║██║     '
echo ' ╚██████╔╝███████╗╚██████╔╝██████╔╝██║  ██║███████╗'
echo '  ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝'
echo -e "${NC}"
echo -e "${CYAN}  Dark Web OSINT Intelligence Platform — Installer${NC}"
echo -e "${YELLOW}  ─────────────────────────────────────────────────${NC}"
echo ""

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo bash install.sh"
fi

# ── Detect distro ─────────────────────────────────────────────────────────────
if ! command -v apt-get &>/dev/null; then
    error "This installer requires a Debian/Ubuntu-based system (apt)."
fi

# ── System dependencies ───────────────────────────────────────────────────────
info "Updating package lists..."
apt-get update -qq

info "Installing system dependencies (tor, python3, pip, git, curl)..."
apt-get install -y -qq tor python3 python3-pip python3-venv git curl nmap 2>/dev/null
success "System packages installed."

# ── Start & enable Tor ────────────────────────────────────────────────────────
info "Enabling and starting Tor service..."
systemctl enable tor --quiet 2>/dev/null || true
systemctl start tor 2>/dev/null || systemctl start tor@default 2>/dev/null || true
sleep 3

if ss -tlnp | grep -q ":9050"; then
    success "Tor is running on port 9050."
else
    warn "Tor did not start automatically. Start it manually with: sudo systemctl start tor"
fi

# ── Clone TorBot ──────────────────────────────────────────────────────────────
TORBOT_DIR="$HOME/TorBot"
if [ -d "$TORBOT_DIR" ]; then
    warn "TorBot already exists at $TORBOT_DIR — pulling latest changes..."
    git -C "$TORBOT_DIR" pull -q
else
    info "Cloning TorBot into $TORBOT_DIR..."
    git clone -q https://github.com/DedSecInside/TorBot.git "$TORBOT_DIR"
    success "TorBot cloned."
fi

# ── Python virtual environment ────────────────────────────────────────────────
info "Creating Python virtual environment at $TORBOT_DIR/venv..."
python3 -m venv "$TORBOT_DIR/venv"
source "$TORBOT_DIR/venv/bin/activate"

info "Installing TorBot Python dependencies..."
pip install -q --upgrade pip
pip install -q -r "$TORBOT_DIR/requirements.txt"
success "Python dependencies installed."

deactivate

# ── Install scanner script ────────────────────────────────────────────────────
SCRIPT_DIR="/opt/GlobalDarkRecon"
info "Installing GlobalDarkRecon scripts to $SCRIPT_DIR..."
mkdir -p "$SCRIPT_DIR"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$REPO_DIR/torbot_scanner.sh" "$SCRIPT_DIR/torbot_scanner.sh"
chmod +x "$SCRIPT_DIR/torbot_scanner.sh"

# Symlink for global access
ln -sf "$SCRIPT_DIR/torbot_scanner.sh" /usr/local/bin/darkrecon
success "darkrecon command installed."

# ── Default targets file ──────────────────────────────────────────────────────
TARGETS_FILE="$HOME/onion_targets.txt"
if [ ! -f "$TARGETS_FILE" ]; then
    info "Creating sample targets file at $TARGETS_FILE..."
    cat > "$TARGETS_FILE" << 'EOF'
# GlobalDarkRecon — Target List
# Add one .onion URL per line. Lines starting with # are ignored.
#
# Example:
# http://example.onion
#
https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion
EOF
    success "Sample targets file created at $TARGETS_FILE"
fi

# ── Patch TorBot path in scanner ─────────────────────────────────────────────
sed -i "s|TORBOT_DIR=\"\$HOME/TorBot\"|TORBOT_DIR=\"$TORBOT_DIR\"|g" "$SCRIPT_DIR/torbot_scanner.sh" 2>/dev/null || true

# Patch venv activation into scanner
sed -i '/TORBOT_DIR=/a source "$TORBOT_DIR/venv/bin/activate"' "$SCRIPT_DIR/torbot_scanner.sh" 2>/dev/null || true

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  TorBot directory : ${CYAN}$TORBOT_DIR${NC}"
echo -e "  Scanner script   : ${CYAN}$SCRIPT_DIR/torbot_scanner.sh${NC}"
echo -e "  Global command   : ${CYAN}darkrecon${NC}"
echo -e "  Targets file     : ${CYAN}$TARGETS_FILE${NC}"
echo -e "  Results saved to : ${CYAN}~/torbot_results/<timestamp>/${NC}"
echo ""
echo -e "${YELLOW}  Next steps:${NC}"
echo -e "  1. Edit your targets: ${CYAN}nano ~/onion_targets.txt${NC}"
echo -e "  2. Run a scan:        ${CYAN}darkrecon${NC}"
echo -e "  3. Custom targets:    ${CYAN}darkrecon /path/to/targets.txt 3${NC}"
echo ""
echo -e "${RED}  Legal: For authorized security research only.${NC}"
echo ""
