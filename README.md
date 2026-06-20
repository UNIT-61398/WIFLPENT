```
  ██╗    ██╗██╗███████╗██╗     ██████╗ ███████╗███╗   ██╗████████╗
  ██║    ██║██║██╔════╝██║     ██╔══██╗██╔════╝████╗  ██║╚══██╔══╝
  ██║ █╗ ██║██║█████╗  ██║     ██████╔╝█████╗  ██╔██╗ ██║   ██║   
  ██║███╗██║██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██║╚██╗██║   ██║   
  ╚███╔███╔╝██║██║     ███████╗██║     ███████╗██║ ╚████║   ██║   
   ╚══╝╚══╝ ╚═╝╚═╝     ╚══════╝╚═╝     ╚══════╝╚═╝  ╚═══╝   ╚═╝   
```
```
╔══════════════════════════════════════════════════════════════════╗
║  ⚡ C A P T U R E   W I - F I   |   C R A C K   P A S S W O R D║
║  ⚡ S E T T I N G   U P   B R U T E F O R C E   A T T A C K   ║
║  🛡️ B Y   T E A M   U N I T - 6 1 3 9 8                       ║
║  🌐 github.com/UNIT-61398                                      ║
╚══════════════════════════════════════════════════════════════════╝
```

# WIFI-PWN — WiFi Penetration Testing Suite

**Fully automated WiFi penetration testing toolkit** for ethical hacking and security research. Captures WPA/WPA2 handshakes and cracks passwords — all from a single hacker-styled terminal interface with `[root@wifi-pwn]~#` prompt.

---

## Features

| # | Feature | Description |
|---|---------|-------------|
| `[1]` | **FULL AUTO** | Complete attack sequence — monitor mode → scan → handshake capture → password cracking |
| `[2]` | **ENABLE MONITOR** | Auto-detects interfaces, kills interfering processes, enables monitor mode |
| `[3]` | **SCAN NETWORKS** | Scan nearby APs with auto-extending duration, BSSID + channel detection |
| `[4]` | **CAPTURE HANDSHAKE** | Set target BSSID/channel, launch deauth attack, capture WPA handshake |
| `[5]` | **CRACK PASSWORD** | aircrack-ng with rockyou.txt wordlist in a separate terminal |
| `[6]` | **CLEANUP** | Stop monitor mode, restart NetworkManager, restore network |
| `[7]` | **MASK ATTACK** | **Hashcat brute-force** with custom charset & configurable length range (8-22 chars) |
| `[8]` | **EXIT** | Exit the tool |

---

## Mask Attack (Option 7)

**Customizable brute-force attack using Hashcat:**

- **Character Sets** — 15 combinations: uppercase, lowercase, digits, special, or any mix
- **Custom Length Range** — Set your own min/max password length (default: 8-22)
- **Smart Extension** — If password not found or attack stopped, extend max length by N chars
- **Auto-Conversion** — Automatically converts `.cap` to hccapx (2500) or 22000 format
- **Separate Terminal** — Runs in a dedicated window with hacker-styled output

### Example flow:

```
[root@wifi-pwn]~# 7
[+] Length range: 8-12 characters
[?] Select (1-15 or q): 11
[?] Start attack with this charset? (y/n): y

# Hashcat tests lengths 8 → 9 → 10 → 11 → 12
# If not found:

[?] Extend max length beyond 12? (Y/n): y
[?] New max length (default: 13):
[+] Extended range: 8-13 chars
```

---

## Requirements

- Kali Linux / Parrot OS / any Debian-based distro
- Wireless adapter with **monitor mode** support
- **Root privileges** (`sudo`)

### Dependencies (auto-installed if missing)

| Package | Purpose |
|---------|---------|
| `aircrack-ng` | Suite: airodump-ng, aireplay-ng, airmon-ng |
| `iwconfig` | Wireless interface detection |
| `hashcat` | GPU-accelerated mask attack (option 7) |
| `hcxtools` | .cap → hccapx conversion |
| `xterm` | New terminal windows for sub-tasks |

---

## Installation

```bash
git clone https://github.com/UNIT-61398/wifi-pwn.git
cd wifi-pwn
chmod +x wifi_pen_test.sh
```

## Usage

```bash
sudo ./wifi_pen_test.sh
```

### Quick Start — Full Auto

```
1. sudo ./wifi_pen_test.sh
2. Select [1] FULL AUTO
3. Select wireless interface
4. Select target network from scan
5. Wait for handshake capture
6. Password will be cracked automatically
```

### Manual Steps

```
1. [2] Enable Monitor Mode
2. [3] Scan Networks → note BSSID & channel
3. [4] Capture Handshake → enter BSSID/channel
4. [5] Crack Password → uses rockyou.txt
5. [6] Cleanup → restore network
```

---

## Output

All captures, wordlists, and cracked passwords are saved to:

```
~/Desktop/WI-FI Pentest/
```

- `*.cap` — Captured WPA handshake
- `*.hccapx` / `*.22000` — Hashcat-ready hash
- `password_cracked.txt` — Cracked password (wordlist)
- `password_mask_attack.txt` — Cracked password (mask attack)

---

## Disclaimer

```
╔══════════════════════════════════════════════════════════════════╗
║  This tool is for AUTHORIZED security testing and educational   ║
║  purposes ONLY. Unauthorized use against networks you do not    ║
║  own or have explicit permission to test is ILLEGAL.            ║
║                                                                ║
║  The authors assume NO LIABILITY and are NOT RESPONSIBLE for    ║
║  any misuse or damage caused by this program.                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## License

MIT License — Copyright (c) 2024 Team UNIT-61398

```
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
```
