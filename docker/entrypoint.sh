#!/bin/bash
# Container entrypoint: starts Tor, waits for it, runs the scanner, fixes result ownership.
set -eo pipefail

# Start Tor in the background
tor &
TOR_PID=$!

echo "[*] Waiting for Tor to initialize on port 9050..."
WAITED=0
until ss -tlnp 2>/dev/null | grep -q ':9050'; do
    sleep 1
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge 30 ]; then
        echo "[-] Tor did not start within 30 seconds. Exiting."
        kill "$TOR_PID" 2>/dev/null || true
        exit 1
    fi
done
echo "[+] Tor is ready."

# Run the scanner; capture exit code even under set -e
/opt/GlobalDarkRecon/torbot_scanner.sh "$@" || EXIT_CODE=$?
EXIT_CODE=${EXIT_CODE:-0}

# Fix result ownership so the host user can read files without sudo.
# HOST_UID / HOST_GID are injected by the darkrecon-docker wrapper.
if [ -n "${HOST_UID:-}" ] && [ -n "${HOST_GID:-}" ]; then
    chown -R "${HOST_UID}:${HOST_GID}" /root/torbot_results/ 2>/dev/null || true
fi

exit "$EXIT_CODE"
