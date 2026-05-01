# GlobalDarkRecon

```
 ██████╗ ██╗      ██████╗ ██████╗  █████╗ ██╗
 ██╔════╝ ██║     ██╔═══██╗██╔══██╗██╔══██╗██║
 ██║  ███╗██║     ██║   ██║██████╔╝███████║██║
 ██║   ██║██║     ██║   ██║██╔══██╗██╔══██║██║
 ╚██████╔╝███████╗╚██████╔╝██████╔╝██║  ██║███████╗
  ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
```

**Automated dark web OSINT intelligence platform for authorized security research.**

Batch-scans `.onion` sites through Tor, crawls to a configurable depth, extracts emails, phone numbers, and Bitcoin addresses, classifies sites by category using an ML classifier, and saves structured reports — all automatically sandboxed under Firejail.

---

## Usage

```bash
# Scan a single URL directly
darkrecon https://somesite.onion

# Scan a single URL with custom crawl depth
darkrecon https://somesite.onion 3

# Scan all URLs in your default targets file (~/onion_targets.txt)
darkrecon

# Scan a custom targets file with custom depth
darkrecon /path/to/targets.txt 3

# Search by keyword and crawl every discovered result
darkrecon --search 'ransomware' --engine http://3bbad7fauom4d6sgppalyqddsqbf5u5p56b5k5uk2zxsy3d6ey2jobad.onion/search

# Keyword search with custom crawl depth
darkrecon --search 'combolist' --engine http://3bbad7fauom4d6sgppalyqddsqbf5u5p56b5k5uk2zxsy3d6ey2jobad.onion/search 3
```

The optional depth argument controls how many levels TorBot crawls from each seed URL (default: `2`; 1–5 recommended).

In `--search` mode the tool fetches the search results page through Tor, extracts every `.onion` link from the HTML, saves them to `discovered_links.txt` in the results directory, then scans each one in sequence. The `--engine` value must point to the search endpoint path, not the engine root — OnionLand Search serves results at `/search?q=`, so the correct value is the full `/search` path as shown above. Common research keywords: `combolist`, `fullz`, `carding`, `botnet`, `ransomware`, `0day`, `doxing`, `escrow`.

### Targets file format

```
# Lines starting with # are ignored
# One URL per line

http://exampleonionaddress1234.onion
http://anotheronionaddress5678.onion
```

### Runtime output

```
[09:42:01] [+] TorBot Multi-Target Scanner
[09:42:01]   URL          : https://somesite.onion
[09:42:01]   Crawl depth  : 2
[09:42:01] [+] Firejail sandbox : ACTIVE
[09:42:01]   Isolation    : caps.drop=all | seccomp | protocol=inet | filesystem blacklists
[09:42:03] [+] Tor SOCKS proxy is running on port 9050
[09:42:03] [+] Loaded 1 target(s)
[09:42:03] [1/1] Scanning: https://somesite.onion
[09:47:03]   [+] Success
```

---

## Features

| Feature | Description |
|---|---|
| Batch scanning | Feed a plain-text list of `.onion` URLs; all targets are scanned in sequence |
| Configurable depth | Crawl 1–5 levels deep from each seed URL |
| Intelligence extraction | Emails, phone numbers, Bitcoin addresses, onion links, site categories |
| NLP classification | ML-based site categorisation (Business, Government, Technology, etc.) |
| Firejail sandbox | Every scan runs isolated — capabilities dropped, credentials blacklisted, raw sockets blocked |
| Tor enforcement | `CAP_NET_RAW` and `AF_PACKET`/`AF_NETLINK` blocked so the SOCKS proxy cannot be bypassed |
| Timestamped results | Each run saves to `~/torbot_results/<timestamp>/` — previous runs never overwritten |
| Timeout protection | Each target is capped at 300 seconds to prevent hangs |
| Python 3.13 support | Fully compatible; binary wheel installs used where source builds fail |
| Idempotent installer | Re-running `install.sh` is safe — patches, venv, and training data are skipped if current |

---

## Security Model (Firejail Sandbox)

Every TorBot invocation is wrapped in a Firejail sandbox automatically. No configuration is required. The sandbox applies the following controls:

### Privilege isolation

| Control | Effect |
|---|---|
| `caps.drop=all` | Removes all Linux capabilities including `CAP_NET_RAW`, `CAP_NET_ADMIN`, `CAP_SYS_PTRACE` |
| `nonewprivs` | Prevents privilege escalation via setuid/setgid binaries |
| `nogroups` | Drops all supplementary group memberships |
| `seccomp` | Default seccomp-bpf filter blocks dangerous syscalls |

### Tor enforcement

| Control | Effect |
|---|---|
| `protocol unix,inet,inet6` | Blocks `AF_PACKET` (raw Ethernet frames) and `AF_NETLINK` (routing/firewall table access) via seccomp |
| `caps.drop=all` | Removes `CAP_NET_RAW` — raw socket creation fails at the kernel level |
| Host network namespace kept | `127.0.0.1:9050` (Tor SOCKS proxy) remains reachable; TorBot routes all HTTP through it by design |

Together these close the two primary kernel-level paths for bypassing a SOCKS5 proxy. TorBot cannot make direct clearnet connections even if its code or a dependency is modified.

### Filesystem restrictions

The following paths are blacklisted and inaccessible inside the sandbox:

- `~/.ssh`, `~/.gnupg` — SSH and GPG keys
- `~/.aws`, `~/.azure`, `~/.config/gcloud`, `~/.kube` — cloud provider credentials
- `~/.netrc`, `~/.pgpass`, `~/.local/share/keyrings`, `~/.password-store` — credential stores
- `~/.bash_history`, `~/.zsh_history`, `~/.histfile` — shell history
- `~/.mozilla`, `~/.config/chromium`, `~/.config/google-chrome` — browser credential databases
- `/etc/shadow`, `/etc/sudoers`, `/etc/sudoers.d`, `/etc/ssh` — system credential files

`private-dev` and `private-tmp` isolate the device namespace and `/tmp`. `/opt/TorBot` is mounted read-only so TorBot cannot modify itself at runtime.

If Firejail is not installed, the scanner falls back to unsandboxed mode and logs a warning.

---

## Requirements

| Dependency | Notes |
|---|---|
| Linux (Kali / Debian / Ubuntu) | Debian/Ubuntu-based system with `apt` required |
| Bash 4+ | Ships with all modern distros |
| Python 3.9 – 3.13 | Installed automatically; Python 3.13 fully supported |
| Tor | Installed and started automatically |
| Git | Used to clone TorBot |
| Firejail | Installed automatically; optional but strongly recommended |
| Root (install only) | `sudo` required for installer; scans run as the invoking user |

---

## Installation

```bash
git clone https://github.com/GlobalReconReport/GlobalDarkRecon.git
cd GlobalDarkRecon
sudo bash install.sh
```

The installer will:

1. Install system packages: `tor`, `python3`, `python3-venv`, `firejail`, `git`, `nmap`
2. Start and enable the Tor service
3. Clone [TorBot](https://github.com/DedSecInside/TorBot) to `/opt/TorBot`
4. Apply the upstream bug-fix patches from `patches/`
5. Patch `requirements.txt` for Python 3.13 compatibility
6. Create a Python virtual environment and install all dependencies
7. Pre-generate NLP training data (so the first scan doesn't stall)
8. Install the scanner to `/opt/GlobalDarkRecon/` and register `darkrecon` globally
9. Deploy the Firejail security profile to `/opt/GlobalDarkRecon/torbot.profile`
10. Create a sample targets file at `~/onion_targets.txt`

The installer is idempotent — it can be re-run to apply updates without losing existing results.

---

## Output Structure

```
~/torbot_results/
└── 20240413_094201/          ← timestamp of the run
    ├── scan_log.txt          ← full timestamped log (ANSI-clean, grep-friendly)
    ├── summary.txt           ← SUCCESS / TIMEOUT / FAILED per target
    └── example1_onion/       ← one directory per target
        ├── stdout.txt        ← TorBot crawl table (titles, URLs, status, emails, categories)
        └── stderr.txt        ← TorBot error output and warnings
```

Each run creates a new timestamped directory. Previous results are never modified.

---

## TorBot Upstream Patches

GlobalDarkRecon automatically applies the following bug fixes to TorBot at install time via `patches/torbot-upstream-fixes.patch`. The patches survive reinstalls and `git pull` updates (already-applied patches are skipped).

| Bug | File | Fix |
|---|---|---|
| **P1** — `_append_node` has no exception handling around HTTP requests. Any SSL error, timeout, or DNS failure on a child link kills the entire scan and loses all results. | `linktree.py` | Wrap `client.get()` in `try/except httpx.RequestError`; log a warning and skip the bad link instead of crashing. |
| **P2** — `get_intel` and `get_bitcoin_address` pass the raw `httpx.Response` object to `re.findall` instead of `.text`, raising `TypeError` on every `--info` scan. The Bitcoin regex also lacks `re.MULTILINE`. | `info.py` | Use `response.text`; add `re.MULTILINE` to the Bitcoin pattern. |
| **P7** — `--url` is marked `required=True` in argparse, so `torbot --version` fails with a parse error before the version logic runs. | `main.py` | Make `--url` optional; move the `--version` check before the URL guard. |
| **P8** — `updater.py` adds a git remote pointing to `TorBoT` (capital B at end), which is not the correct repository URL. | `updater.py` | Correct to `TorBot`. |

---

## Python 3.13 Compatibility

TorBot's `requirements.txt` pins several packages that do not have Python 3.13 wheels. The installer patches these automatically:

| Issue | Fix |
|---|---|
| `pyinstaller==6.8.0` — no Python 3.13 wheel | Patched to `6.10.0` |
| `pyinstaller-hooks-contrib==2024.6` — must match PyInstaller | Patched to `2024.8` |
| `sklearn==0.0` — broken stub package, fails on 3.13 | Removed |
| `numpy`, `scikit-learn`, `scipy` — source builds fail on 3.13 | Installed with `--only-binary=:all:` before the main requirements pass |

---

## Repository Structure

```
GlobalDarkRecon/
├── install.sh                 Main installer (native + optional Docker path)
├── torbot_scanner.sh          Batch scanner — the darkrecon command
├── firejail/
│   └── torbot.profile         Firejail security profile for TorBot
├── patches/
│   └── torbot-upstream-fixes.patch   Bug fixes applied to TorBot post-clone
├── docker/
│   ├── Dockerfile             Python 3.11 container build (alternative install path)
│   ├── entrypoint.sh          Container startup — starts Tor, runs scanner, fixes ownership
│   └── darkrecon-docker.sh    Transparent darkrecon wrapper for Docker mode
└── .gitignore                 Excludes scan results, target lists, secrets, and logs
```

---

## Legal Disclaimer

**For authorized security research, penetration testing, and lawful OSINT investigations only.**

Unauthorized access to computer systems is illegal. The authors of GlobalDarkRecon accept no liability for misuse. You are solely responsible for ensuring your use complies with all applicable local, national, and international laws. By using this tool you agree to these terms.
