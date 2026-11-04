# WIFLPENT — WiFi Penetration Testing Suite

WIFLPENT is a WiFi penetration-testing suite for authorized testing, ethical hacking, and security research. It captures WPA/WPA2 handshakes and recovers passwords, all from a single terminal interface.

> **Authorized testing only:** This tool is for AUTHORIZED security testing and educational purposes ONLY. Unauthorized use against networks you do not own or have explicit permission to test is ILLEGAL. The authors assume NO LIABILITY and are NOT RESPONSIBLE for any misuse or damage caused by this program.

## Version

- **Project name:** WIFLPENT (unchanged)
- **Script:** `wifi_pen_test.sh`
- **Version:** 2.3.2 (full build)
- **Team:** UNIT-61398

> **Known issue — Option [6] MASK ATTACK is not working properly yet.** Option 6 is listed in the menu, but it is not yet working reliably. Do not rely on it until a future update fixes it. All other menu options are presented as in the script.

---

## Features

| # | Feature | Description |
| --- | --- | --- |
| `[1]` | **FULL AUTO** | Complete sequence — monitor mode, scan, handshake capture, then password cracking |
| `[2]` | **ENABLE MONITOR MODE** | Interface detection and monitor-mode setup, with recovery of the original mode |
| `[3]` | **SCAN NETWORKS** | Scan nearby access points, with BSSID and channel detection |
| `[4]` | **CAPTURE HANDSHAKE** | Set target, capture a WPA handshake |
| `[5]` | **CRACK PASSWORD** | Wordlist-based password recovery in a separate terminal |
| `[6]` | **MASK ATTACK — Hashcat** | Mask-based recovery — **not working properly yet, see Known issue above** |
| `[7]` | **RESTORE NETWORK MANAGER** | Restore NetworkManager / managed networking |
| `[8]` | **CLEANUP / RECOVER** | Stop monitor mode, restore services and network state, recover a previous run state |
| `[9]` | **DIAGNOSTICS / TROUBLESHOOT** | Interface, PHY, rfkill, service, and firmware diagnostics |
| `[10]` | **EXIT** | Clean up and exit the tool |

### Mask Attack (Option 6) — status

Mask attack is intended as a Hashcat-based option with a custom length range and automatic capture-to-hash conversion, with a John the Ripper CPU fallback in the script. **It is currently not working properly, so treat it as experimental / under repair.** Use options 1–5 and 7–9 for the working workflow, and check a future release for a fixed mask attack.

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
| `hashcat` | Mask attack (option 6, currently not working properly) |
| `hcxtools` | .cap to hash conversion |
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

Then choose an option from the menu (options 1–10, as listed in Features above).

Other supported commands:

```bash
sudo ./wifi_pen_test.sh --check
sudo ./wifi_pen_test.sh --version
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
- `password_mask_*.txt` — Mask attack result files, when mask attack works

---

## Disclaimer

This tool is for AUTHORIZED security testing and educational purposes ONLY. Unauthorized use against networks you do not own or have explicit permission to test is ILLEGAL.

The authors assume NO LIABILITY and are NOT RESPONSIBLE for any misuse or damage caused by this program.

Use WIFLPENT only on networks you own or have explicit, written permission to test.

---

## License

MIT License — Copyright (c) 2026 Team UNIT-61398. See the `LICENSE` file for the full license text.
