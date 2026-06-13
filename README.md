# WIFLPENT — WiFi Penetration Testing Suite

**Developed by TEAM UNIT-61398**

A fully automated WiFi penetration testing toolkit for ethical hacking and security research. Captures WPA/WPA2 handshakes and cracks passwords — all from a single hacker-styled terminal interface.

## Features

- **Full Auto Mode** — Complete attack sequence: monitor mode → scan → handshake capture → password cracking
- **Targeted Handshake Capture** — Specify BSSID/channel, launch deauth attack in a new terminal
- **WPA/WPA2 Password Cracking** — Uses aircrack-ng with rockyou.txt wordlist in a separate terminal
- **Network Scanning** — Scan nearby APs with auto-extending duration
- **Smart Monitor Mode** — Auto-detects interfaces, kills interfering processes, handles NetworkManager
- **Auto Wordlist Management** — Finds/extracts/installs rockyou.txt automatically
- **Brute Force** (Under Development)
- **Cleanup** — Restores network to normal state

## Requirements

- Kali Linux or any Debian-based distro
- Wireless adapter with monitor mode support
- Root privileges

### Dependencies (auto-installed if missing)

- `aircrack-ng` / `airodump-ng` / `aireplay-ng` / `airmon-ng`
- `iwconfig`
- `xterm` (for new terminal windows)

## Installation

```bash
git clone https://github.com/UNIT-61398/WIFLPENT.git
cd WIFLPENT
chmod +x wifi_pen_test.sh
```

## Usage

```bash
sudo ./wifi_pen_test.sh
```

### Menu Options

| Option | Description |
|--------|-------------|
| `[1]` | Full Auto — complete attack sequence |
| `[2]` | Enable Monitor Mode |
| `[3]` | Scan Networks |
| `[4]` | Capture Handshake — set target & deauth |
| `[5]` | Crack Password |
| `[6]` | Cleanup — stop monitor & restart network |
| `[7]` | Brute Force (Under Development) |
| `[8]` | Exit |

### Quick Start

1. Run `sudo ./wifi_pen_test.sh`
2. Select `[2]` to enable monitor mode on your wireless interface
3. Select `[3]` to scan for target networks
4. Note the BSSID and channel of your target
5. Select `[4]`, enter BSSID/channel, and wait for the handshake
6. Select `[5]` to crack the captured handshake
7. Select `[6]` to restore normal network operation

## Output

All captures and wordlists are saved to `~/Desktop/WI-FI Pentest/`.

## Disclaimer

This tool is for **authorized security testing and educational purposes only**. Unauthorized use against networks you do not own or have explicit permission to test is illegal. The authors assume no liability and are not responsible for any misuse or damage caused by this program.

## License

MIT License

Copyright (c) 2024 Team UNIT-61398

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
