#!/bin/bash
# darkrecon-docker — proxies the darkrecon command transparently into the
# globaldark-recon container. Drop-in replacement for torbot_scanner.sh.
set -eo pipefail

IMAGE="globaldark-recon:latest"
TARGETS_ARG="${1:-$HOME/onion_targets.txt}"
DEPTH="${2:-2}"
RESULTS_DIR="$HOME/torbot_results"

mkdir -p "$RESULTS_DIR"

TARGETS_FILE="$(realpath "$TARGETS_ARG" 2>/dev/null || echo "$TARGETS_ARG")"

# First-run bootstrap: create a sample targets file and exit so the user can edit it
if [ ! -f "$TARGETS_FILE" ]; then
    cat > "$TARGETS_FILE" << 'EOF'
# GlobalDarkRecon — Target List
# Add one .onion URL per line. Lines starting with # are ignored.
#
# Example:
# http://example.onion
#
https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion
EOF
    echo -e "\033[0;32m[+]\033[0m Sample targets file created at $TARGETS_FILE. Edit it then run again."
    exit 0
fi

# Verify the Docker image exists
if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo -e "\033[0;31m[-]\033[0m Docker image '$IMAGE' not found."
    echo "    Rebuild with: sudo docker build -t $IMAGE -f /path/to/GlobalDarkRecon/docker/Dockerfile /path/to/GlobalDarkRecon"
    exit 1
fi

# Allocate a pseudo-TTY only when stdin is a terminal (safe for cron / pipes)
TTY_FLAG=''
[ -t 0 ] && TTY_FLAG='--tty'

exec docker run --rm --interactive $TTY_FLAG \
    --name "darkrecon-$$" \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    -v "${TARGETS_FILE}:/root/onion_targets.txt:ro" \
    -v "${RESULTS_DIR}:/root/torbot_results" \
    "$IMAGE" \
    /root/onion_targets.txt "$DEPTH"
