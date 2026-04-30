# Firejail security profile for TorBot OSINT scanner
#
# Design goals:
#   1. Block access to credentials and key material on the host filesystem
#   2. Drop all Linux capabilities (prevents raw sockets, privilege escalation)
#   3. Restrict socket types so AF_PACKET / AF_NETLINK are unavailable
#      (kernel-level network bypass requires one of these)
#   4. Keep the host network namespace so 127.0.0.1:9050 (Tor SOCKS) is
#      reachable — TorBot's httpx routes everything through it by design
#
# Applied by torbot_scanner.sh via:
#   firejail --profile=/opt/GlobalDarkRecon/torbot.profile \
#            --read-only=/opt/TorBot                       \
#            --env="PYTHONPATH=/opt/TorBot/src"            \
#            -- /opt/TorBot/venv/bin/python3 main.py ...

quiet

# ── Privilege hardening ───────────────────────────────────────────────────────
# Drop the full capability bounding set: no raw sockets (CAP_NET_RAW),
# no routing table changes (CAP_NET_ADMIN), no ptrace, no module loading.
caps.drop all

# Prevent acquiring new privileges via setuid/setgid binaries
nonewprivs

# Drop supplementary groups
nogroups

# ── Syscall filtering ─────────────────────────────────────────────────────────
# Default seccomp filter blocks the most dangerous syscalls
seccomp

# Allow only IPv4, IPv6, and Unix domain sockets.
# Blocks AF_PACKET (raw ethernet), AF_NETLINK (routing/firewall),
# AF_BLUETOOTH, AF_TIPC — all usable to bypass the SOCKS5 proxy.
protocol unix,inet,inet6

# ── Filesystem isolation ──────────────────────────────────────────────────────
private-dev
private-tmp

# SSH and GPG keys
blacklist ${HOME}/.ssh
blacklist ${HOME}/.gnupg

# Cloud provider credentials
blacklist ${HOME}/.aws
blacklist ${HOME}/.azure
blacklist ${HOME}/.config/gcloud
blacklist ${HOME}/.kube

# Password and credential stores
blacklist ${HOME}/.netrc
blacklist ${HOME}/.pgpass
blacklist ${HOME}/.local/share/keyrings
blacklist ${HOME}/.password-store

# Shell history (contains commands, hostnames, tokens)
blacklist ${HOME}/.bash_history
blacklist ${HOME}/.zsh_history
blacklist ${HOME}/.histfile

# Browser credential databases
blacklist ${HOME}/.mozilla
blacklist ${HOME}/.config/chromium
blacklist ${HOME}/.config/google-chrome

# System credential files
blacklist /etc/shadow
blacklist /etc/shadow-
blacklist /etc/gshadow
blacklist /etc/sudoers
blacklist /etc/sudoers.d
blacklist /etc/ssh
