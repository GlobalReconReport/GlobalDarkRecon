# GlobalDarkRecon

Automated dark web OSINT intelligence platform. Batch scans .onion sites through Tor, crawls to configurable depth, and extracts emails, crypto wallets, PGP keys, onion links and usernames.

## Scripts
- torbot_scanner.sh — multi-target scanner
- intel_extract.sh — intelligence extractor
Requirements
- Linux (Kali, Ubuntu, Debian recommended)
- Python 3.9+
- Tor
- pip

Installation

git clone https://github.com/yourname/TorBot.git
cd TorBot
pip install -r requirements.txt

Start Tor

sudo systemctl start tor

Run scanner

chmod +x torbot_scan.sh
./torbot_scan.sh