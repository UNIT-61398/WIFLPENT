# WIFLPENT — WiFi Penetration Testing Suite

WIFLPENT is a WiFi penetration-testing suite for authorized testing, ethical hacking, and security research. It captures WPA/WPA2 handshakes and cracks passwords, all from a single terminal interface with a `[root@wifi-pwn]~#` prompt.

> **Authorized testing only:** This tool is for AUTHORIZED security testing and educational purposes ONLY. Unauthorized use against networks you do not own or have explicit permission to test is ILLEGAL. The authors assume NO LIABILITY and are NOT RESPONSIBLE for any misuse or damage caused by this program.

---

## Features

| # | Feature | Description |
| --- | --- | --- |
| `[1]` | **FULL AUTO** | Complete attack sequence — monitor mode → scan → handshake capture → password cracking |
| `[2]` | **ENABLE MONITOR** | Auto-detects interfaces, kills interfering processes, enables monitor mode |
| `[3]` | **SCAN NETWORKS** | Scan nearby APs with auto-extending duration, BSSID + channel detection |
| `[4]` | **CAPTURE HANDSHAKE** | Set target BSSID/channel, launch deauth attack, capture WPA handshake |
| `[5]` | **CRACK PASSWORD** | aircrack-ng with rockyou.txt wordlist in a separate terminal |
| `[6]` | **CLEANUP** | Stop monitor mode, restart NetworkManager, restore network |
| `[7]` | **MASK ATTACK** | Hashcat brute-force with custom charset & configurable length range (8-22 chars) |
| `[8]` | **EXIT** | Exit the tool |

### Mask Attack (Option 7)

Customizable brute-force attack using Hashcat:

- **Character Sets** — 15 combinations: uppercase, lowercase, digits, special, or any mix
- **Custom Length Range** — Set your own min/max password length (default: 8-22)
- **Smart Extension** — If password not found or attack stopped, extend max length by N chars
- **Auto-Conversion** — Automatically converts `.cap` to hccapx (2500) or 22000 format
- **Separate Terminal** — Runs in a dedicated window with hacker-styled output

#### Example flow

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
- Root privileges (`sudo`)

### Dependencies (auto-installed if missing)

| Package | Purpose |
| --- | --- |
| `aircrack-ng` | Suite: airodump-ng, aireplay-ng, airmon-ng |
| `iwconfig` | Wireless interface detection |
| `hashcat` | GPU-accelerated mask attack (option 7) |
| `hcxtools` | .cap → hccapx conversion |
| `xterm` | New terminal windows for sub-tasks |

---

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

Then choose an option from the menu (options 1-8, as listed in Features above).

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

## Outputs

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

This tool is for AUTHORIZED security testing and educational purposes ONLY. Unauthorized use against networks you do not own or have explicit permission to test is ILLEGAL.

The authors assume NO LIABILITY and are NOT RESPONSIBLE for any misuse or damage caused by this program.

Use WIFLPENT only on networks you own or have explicit, written permission to test.

---

## License

MIT License — Copyright (c) 2026 Team UNIT-61398. See the `LICENSE` file for the full license text.
