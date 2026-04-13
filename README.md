# GlobalDarkRecon

```
 ██████╗ ██╗      ██████╗ ██████╗  █████╗ ██╗     
 ██╔════╝ ██║     ██╔═══██╗██╔══██╗██╔══██╗██║     
 ██║  ███╗██║     ██║   ██║██████╔╝███████║██║     
 ██║   ██║██║     ██║   ██║██╔══██╗██╔══██║██║     
 ╚██████╔╝███████╗╚██████╔╝██████╔╝██║  ██║███████╗
  ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝

 ██████╗  █████╗ ██████╗ ██╗  ██╗██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
 ██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║
 ██║  ██║███████║██████╔╝█████╔╝ ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║
 ██║  ██║██╔══██║██╔══██╗██╔═██╗ ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║
 ██████╔╝██║  ██║██║  ██║██║  ██╗██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║
 ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
```

> **Automated dark web OSINT intelligence platform.**  
> Batch-scans `.onion` sites through Tor, crawls to a configurable depth, and extracts emails, crypto wallet addresses, PGP keys, hidden service links, and usernames — all saved to structured JSON reports.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Install](#quick-install)
- [Manual Installation](#manual-installation)
- [Commands & Usage](#commands--usage)
- [Step-by-Step Walkthrough](#step-by-step-walkthrough)
- [Output Structure](#output-structure)
- [Legal Disclaimer](#legal-disclaimer)

---

## Features

| Feature | Description |
|---|---|
| Batch scanning | Feed a plain-text list of `.onion` URLs and scan all of them in one run |
| Configurable depth | Crawl 1–5 levels deep from each seed URL |
| Intelligence extraction | Emails, Bitcoin/Monero wallets, PGP keys, onion links, usernames |
| Structured reports | Per-target JSON output + a human-readable summary |
| Tor health check | Auto-detects and starts the Tor SOCKS proxy before scanning |
| Timestamped results | Every run gets its own `~/torbot_results/<timestamp>/` folder |
| Timeout protection | Each target is capped at 300 seconds to prevent hangs |
| Color terminal output | Live status with SUCCESS / TIMEOUT / FAILED per target |

---

## Requirements

| Dependency | Version | Purpose |
|---|---|---|
| Linux (Kali / Ubuntu / Debian) | Any recent | Supported OS |
| Bash | 4+ | Runs the scanner |
| Python | 3.9+ | Runs TorBot crawl engine |
| Tor | Any | SOCKS5 proxy on port 9050 |
| Git | Any | Clones TorBot |
| pip / venv | Any | Python dependency isolation |

---

## Quick Install

> Requires `sudo`. Tested on Kali Linux, Ubuntu 22.04+, and Debian 12.

```bash
git clone https://github.com/GlobalReconReport/GlobalDarkRecon.git
cd GlobalDarkRecon
sudo bash install.sh
```

The installer will:
1. Install `tor`, `python3`, `pip`, `git` via `apt`
2. Start and enable the Tor service
3. Clone [TorBot](https://github.com/DedSecInside/TorBot) to `~/TorBot`
4. Create a Python virtual environment and install all dependencies
5. Install the scanner to `/opt/GlobalDarkRecon/`
6. Register the `darkrecon` command globally (`/usr/local/bin/darkrecon`)
7. Create a sample targets file at `~/onion_targets.txt`

---

## Manual Installation

If you prefer to install step by step:

```bash
# 1. Install system packages
sudo apt update
sudo apt install -y tor python3 python3-pip python3-venv git curl

# 2. Start Tor
sudo systemctl enable tor
sudo systemctl start tor

# 3. Clone TorBot
git clone https://github.com/DedSecInside/TorBot.git ~/TorBot

# 4. Set up Python environment
python3 -m venv ~/TorBot/venv
source ~/TorBot/venv/bin/activate
pip install -r ~/TorBot/requirements.txt
deactivate

# 5. Clone GlobalDarkRecon
git clone https://github.com/GlobalReconReport/GlobalDarkRecon.git
cd GlobalDarkRecon
chmod +x torbot_scanner.sh

# 6. (Optional) Install globally
sudo cp torbot_scanner.sh /usr/local/bin/darkrecon
sudo chmod +x /usr/local/bin/darkrecon
```

---

## Commands & Usage

### Basic syntax

```
darkrecon [targets_file] [depth]
```

| Argument | Default | Description |
|---|---|---|
| `targets_file` | `~/onion_targets.txt` | Path to a plain-text file of `.onion` URLs (one per line) |
| `depth` | `2` | How many levels deep to crawl from each seed URL (1–5 recommended) |

### Examples

```bash
# Run with defaults (~/onion_targets.txt, depth 2)
darkrecon

# Use a custom targets file
darkrecon ~/my_targets.txt

# Custom targets file AND crawl depth
darkrecon ~/my_targets.txt 3

# Run directly without global install
./torbot_scanner.sh ~/my_targets.txt 2
```

### Targets file format

```
# Lines starting with # are comments and are ignored
# One URL per line, http or https

http://exampleonion1234567890abcdef.onion
http://anotheronionaddresshere.onion
```

### Check Tor status

```bash
# Verify Tor SOCKS proxy is running
ss -tlnp | grep 9050

# Start/restart Tor manually
sudo systemctl start tor
sudo systemctl status tor
```

---

## Step-by-Step Walkthrough

### Step 1 — Clone and install

```bash
git clone https://github.com/GlobalReconReport/GlobalDarkRecon.git
cd GlobalDarkRecon
sudo bash install.sh
```

You should see green `[+]` lines as each component installs. When finished, the installer prints a summary showing where everything landed.

---

### Step 2 — Add your targets

Open the targets file in any text editor:

```bash
nano ~/onion_targets.txt
```

Add one `.onion` URL per line:

```
http://exampleonionsite1.onion
http://exampleonionsite2.onion
http://exampleonionsite3.onion
```

Save and close (`Ctrl+O`, `Enter`, `Ctrl+X` in nano).

---

### Step 3 — Verify Tor is running

```bash
sudo systemctl status tor
```

Look for `Active: active (running)`. If it is stopped:

```bash
sudo systemctl start tor
```

Confirm the SOCKS proxy is up on port 9050:

```bash
ss -tlnp | grep 9050
```

---

### Step 4 — Run the scanner

```bash
darkrecon
```

Or with a custom depth:

```bash
darkrecon ~/onion_targets.txt 3
```

You will see the ASCII banner and then live per-target status:

```
[09:42:01] [+] TorBot Multi-Target Scanner
[09:42:01]   Targets file : /home/user/onion_targets.txt
[09:42:01]   Crawl depth  : 2
[09:42:01]   Results dir  : /home/user/torbot_results/20240413_094201
[09:42:04] [+] Tor SOCKS proxy is running on port 9050
[09:42:04] [+] Loaded 3 target(s)
[09:42:04] [1/3] Scanning: http://exampleonionsite1.onion
[09:47:04]   [+] Success
[09:47:09] [2/3] Scanning: http://exampleonionsite2.onion
[09:52:09]   [!] Timeout after 300s
[09:52:14] [3/3] Scanning: http://exampleonionsite3.onion
[09:53:01]   [-] Failed (exit code: 1)
```

---

### Step 5 — Review the results

All output is saved under `~/torbot_results/<timestamp>/`:

```bash
ls ~/torbot_results/
# 20240413_094201/

ls ~/torbot_results/20240413_094201/
# exampleonionsite1_onion/   scan_log.txt   summary.txt
```

Read the scan summary:

```bash
cat ~/torbot_results/20240413_094201/summary.txt
```

```
-------------------------------------------
Scan started: Sun Apr 13 09:42:01 UTC 2024
-------------------------------------------
SUCCESS | http://exampleonionsite1.onion
TIMEOUT | http://exampleonionsite2.onion
FAILED  | http://exampleonionsite3.onion
-------------------------------------------
Scan completed: Sun Apr 13 09:58:44 UTC 2024
```

Inspect per-target extracted intelligence:

```bash
ls ~/torbot_results/20240413_094201/exampleonionsite1_onion/
# stdout.txt   stderr.txt   torbot_output.json

cat ~/torbot_results/20240413_094201/exampleonionsite1_onion/torbot_output.json
```

---

### Step 6 — Iterate

- Add more targets to `~/onion_targets.txt` and re-run
- Increase depth for deeper crawls: `darkrecon ~/onion_targets.txt 4`
- Each run creates a new timestamped folder — previous results are never overwritten

---

## Output Structure

```
~/torbot_results/
└── 20240413_094201/              ← Timestamp of the run
    ├── scan_log.txt              ← Full timestamped log of all events
    ├── summary.txt               ← SUCCESS / TIMEOUT / FAILED per target
    └── exampleonionsite1_onion/  ← Sanitized target name (one folder per target)
        ├── stdout.txt            ← TorBot crawl output
        ├── stderr.txt            ← TorBot error output
        └── *.json                ← Extracted intelligence (emails, wallets, links, keys)
```

---

## Legal Disclaimer

> **For authorized security research, penetration testing, and lawful OSINT investigations only.**  
> Unauthorized access to computer systems is illegal. The authors of GlobalDarkRecon accept no liability for misuse. You are solely responsible for ensuring your use complies with all applicable local, national, and international laws. By using this tool you agree to these terms.
