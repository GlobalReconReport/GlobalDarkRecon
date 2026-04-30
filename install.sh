#!/bin/bash
# GlobalDarkRecon — Installer
# https://github.com/GlobalReconReport/GlobalDarkRecon

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[*]${NC} $1"; }
success() { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[-]${NC} $1"; exit 1; }
ask()     { echo -e "${YELLOW}[?]${NC} $1"; }

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

# ── Core variables (defined early — used by both install paths) ───────────────
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TORBOT_DIR="/opt/TorBot"
SCRIPT_DIR="/opt/GlobalDarkRecon"
TARGETS_FILE="$REAL_HOME/onion_targets.txt"

# ── Detect distro ─────────────────────────────────────────────────────────────
if ! command -v apt-get &>/dev/null; then
    error "This installer requires a Debian/Ubuntu-based system (apt)."
fi

# ── Docker detection and prompt ───────────────────────────────────────────────
USE_DOCKER=false
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    if [ -t 0 ]; then
        echo ""
        ask "Docker is available. Use the Docker-based installation?"
        ask "  Docker: runs TorBot in a Python 3.11 container — avoids dependency conflicts"
        ask "  Native: installs directly on this system (Python $(python3 --version 2>&1 | awk '{print $2}'))"
        ask "Use Docker? [y/N]: "
        read -r docker_choice </dev/tty
        case "$docker_choice" in
            [yY][eE][sS]|[yY]) USE_DOCKER=true ;;
        esac
    else
        info "Non-interactive mode — defaulting to native install. (Pass USE_DOCKER=1 to override.)"
        [ "${USE_DOCKER_ENV:-0}" = "1" ] && USE_DOCKER=true
    fi
else
    if [ "${USE_DOCKER_ENV:-0}" = "1" ]; then
        error "USE_DOCKER=1 requested but Docker is not available or the daemon is not running."
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# DOCKER INSTALL PATH
# ══════════════════════════════════════════════════════════════════════════════
if $USE_DOCKER; then
    info "Starting Docker-based installation..."

    info "Building GlobalDarkRecon image (this takes a few minutes on first run)..."
    docker build \
        -t globaldark-recon:latest \
        -f "$REPO_DIR/Dockerfile" \
        "$REPO_DIR" \
        || error "Docker build failed. Check output above."
    success "Docker image built: globaldark-recon:latest"

    info "Installing darkrecon wrapper to $SCRIPT_DIR..."
    mkdir -p "$SCRIPT_DIR"
    cp "$REPO_DIR/docker/darkrecon-docker.sh" "$SCRIPT_DIR/darkrecon-docker.sh"
    chmod +x "$SCRIPT_DIR/darkrecon-docker.sh"
    chown "$REAL_USER":"$REAL_USER" "$SCRIPT_DIR/darkrecon-docker.sh"
    ln -sf "$SCRIPT_DIR/darkrecon-docker.sh" /usr/local/bin/darkrecon
    success "darkrecon command installed (Docker mode)."

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
        chown "$REAL_USER":"$REAL_USER" "$TARGETS_FILE"
        success "Sample targets file created at $TARGETS_FILE"
    fi

    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation complete! (Docker mode)${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Docker image     : ${CYAN}globaldark-recon:latest${NC}"
    echo -e "  Wrapper script   : ${CYAN}$SCRIPT_DIR/darkrecon-docker.sh${NC}"
    echo -e "  Global command   : ${CYAN}darkrecon${NC}"
    echo -e "  Targets file     : ${CYAN}$TARGETS_FILE${NC}"
    echo -e "  Results saved to : ${CYAN}$REAL_HOME/torbot_results/<timestamp>/${NC}"
    echo ""
    echo -e "${YELLOW}  Next steps:${NC}"
    echo -e "  1. Edit your targets: ${CYAN}nano ~/onion_targets.txt${NC}"
    echo -e "  2. Run a scan:        ${CYAN}darkrecon${NC}"
    echo -e "  3. Custom targets:    ${CYAN}darkrecon /path/to/targets.txt 3${NC}"
    echo ""
    echo -e "${CYAN}  Note: Docker mode does not require Tor on the host — Tor runs inside the container.${NC}"
    echo ""
    echo -e "${RED}  Legal: For authorized security research only.${NC}"
    echo ""
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# NATIVE INSTALL PATH
# ══════════════════════════════════════════════════════════════════════════════

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
if [ -d "$TORBOT_DIR" ]; then
    warn "TorBot already exists at $TORBOT_DIR — pulling latest changes..."
    git -C "$TORBOT_DIR" pull -q
else
    info "Cloning TorBot into $TORBOT_DIR..."
    git clone -q https://github.com/DedSecInside/TorBot.git "$TORBOT_DIR"
    success "TorBot cloned."
fi

# ── Apply GlobalDarkRecon upstream patches ────────────────────────────────────
PATCHES_DIR="$REPO_DIR/patches"
if [ -d "$PATCHES_DIR" ]; then
    for patch_file in "$PATCHES_DIR"/*.patch; do
        [ -f "$patch_file" ] || continue
        info "Checking patch: $(basename "$patch_file")..."
        if git -C "$TORBOT_DIR" apply --check "$patch_file" 2>/dev/null; then
            git -C "$TORBOT_DIR" apply "$patch_file"
            success "Applied: $(basename "$patch_file")"
        else
            warn "Already applied or inapplicable: $(basename "$patch_file") — skipping."
        fi
    done
fi

# ── Patch requirements.txt for Python 3.13 compatibility ─────────────────────
info "Patching TorBot requirements.txt for Python 3.13 compatibility..."
REQS="$TORBOT_DIR/requirements.txt"

# pyinstaller 6.8.0 does not have a Python 3.13 wheel; 6.10.0 does
sed -i 's/pyinstaller==6\.8\.0/pyinstaller==6.10.0/' "$REQS"

# pyinstaller-hooks-contrib must align with pyinstaller; 2024.8 matches 6.10.0
sed -i 's/pyinstaller-hooks-contrib==2024\.6/pyinstaller-hooks-contrib==2024.8/' "$REQS"

# sklearn==0.0 is a broken stub that has no Python 3.13 wheel
sed -i '/^sklearn==0\.0/d' "$REQS"

success "requirements.txt patched."

# ── Python virtual environment ────────────────────────────────────────────────
info "Creating Python virtual environment at $TORBOT_DIR/venv..."
python3 -m venv "$TORBOT_DIR/venv"
source "$TORBOT_DIR/venv/bin/activate"

info "Upgrading pip..."
pip install -q --upgrade pip

# numpy / scikit-learn / scipy have no source build support on Python 3.13;
# install pre-built wheels before the full requirements pass so pip doesn't
# attempt (and fail) to compile them.
info "Installing binary-only scientific packages (numpy, scikit-learn, scipy)..."
pip install -q --only-binary=:all: numpy scikit-learn scipy

info "Installing remaining TorBot Python dependencies..."
pip install -q -r "$REQS"
success "Python dependencies installed."

deactivate

# ── Pre-generate NLP training data while still root ───────────────────────────
# gather_data.py uses os.chdir() to the nlp/ dir, so running it now (as root,
# who owns the files) writes training_data/ before the chown flip below.
# Without this, the first scan as a non-root user hits a PermissionError.
NLP_DIR="$TORBOT_DIR/src/torbot/modules/nlp"
if [ ! -d "$NLP_DIR/training_data" ]; then
    info "Pre-generating NLP training data (this takes ~30s)..."
    (cd "$NLP_DIR" && PYTHONPATH="$TORBOT_DIR/src" "$TORBOT_DIR/venv/bin/python3" gather_data.py) \
        && success "NLP training data generated." \
        || warn "NLP training data generation failed — TorBot will retry on first scan."
else
    info "NLP training data already present, skipping."
fi

# ── Fix TorBot directory ownership so the invoking user can write to it ───────
info "Setting TorBot directory ownership to $REAL_USER..."
chown -R "$REAL_USER":"$REAL_USER" "$TORBOT_DIR"
success "TorBot permissions set."

# ── Install scanner script ────────────────────────────────────────────────────
info "Installing GlobalDarkRecon scripts to $SCRIPT_DIR..."
mkdir -p "$SCRIPT_DIR"
cp "$REPO_DIR/torbot_scanner.sh" "$SCRIPT_DIR/torbot_scanner.sh"
chmod +x "$SCRIPT_DIR/torbot_scanner.sh"
ln -sf "$SCRIPT_DIR/torbot_scanner.sh" /usr/local/bin/darkrecon
success "darkrecon command installed (native mode)."

# ── Default targets file ──────────────────────────────────────────────────────
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
    chown "$REAL_USER":"$REAL_USER" "$TARGETS_FILE"
    success "Sample targets file created at $TARGETS_FILE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation complete! (native mode)${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  TorBot directory : ${CYAN}$TORBOT_DIR${NC}"
echo -e "  Scanner script   : ${CYAN}$SCRIPT_DIR/torbot_scanner.sh${NC}"
echo -e "  Global command   : ${CYAN}darkrecon${NC}"
echo -e "  Targets file     : ${CYAN}$TARGETS_FILE${NC}"
echo -e "  Results saved to : ${CYAN}$REAL_HOME/torbot_results/<timestamp>/${NC}"
echo ""
echo -e "${YELLOW}  Next steps:${NC}"
echo -e "  1. Edit your targets: ${CYAN}nano ~/onion_targets.txt${NC}"
echo -e "  2. Run a scan:        ${CYAN}darkrecon${NC}"
echo -e "  3. Custom targets:    ${CYAN}darkrecon /path/to/targets.txt 3${NC}"
echo ""
echo -e "${RED}  Legal: For authorized security research only.${NC}"
echo ""
