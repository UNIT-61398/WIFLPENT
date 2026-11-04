# WIFLPENT — WiFi Penetration Testing Suite

WIFLPENT is a WiFi penetration-testing suite for authorized testing, ethical hacking, and security research. It works from a single terminal menu, with built-in safety, state recovery, and diagnostics, so an interrupted run does not leave the system networking broken.

> **Authorized testing only:** This tool is for AUTHORIZED security testing and educational purposes ONLY. Unauthorized use against networks you do not own or have explicit permission to test is ILLEGAL. The authors assume NO LIABILITY and are NOT RESPONSIBLE for any misuse or damage caused by this program.

## Version

- **Project name:** WIFLPENT (unchanged)
- **Script:** `wifi_pen_test.sh`
- **Version:** 2.3.2 (full build)
- **Team:** UNIT-61398

> **Known issue — Option [6] MASK ATTACK is not working properly yet.** Option 6 is in the menu, but it is not yet working reliably. Do not rely on it until a future update fixes it.

---

## Menu — all options

| # | Option | What it does |
| --- | --- | --- |
| `[1]` | **FULL AUTO** | Runs the full workflow in order: checks, monitor mode, scan, target selection, handshake capture, network restore, wordlist preparation, then password cracking |
| `[2]` | **ENABLE MONITOR MODE** | Detects wireless interfaces, shows managed and already-monitor interfaces separately, and enables monitor mode with verification |
| `[3]` | **SCAN NETWORKS** | Scans nearby access points and lets you pick a target from the list |
| `[4]` | **CAPTURE HANDSHAKE** | Sets a target and captures a WPA handshake for that target |
| `[5]` | **CRACK PASSWORD** | Recovers a password from the latest capture, using a wordlist, in a separate terminal |
| `[6]` | **MASK ATTACK — Hashcat** | Mask-based recovery — **not working properly yet, see Known issue above** |
| `[7]` | **RESTORE NETWORK MANAGER** | Explicitly restores managed networking, NetworkManager, and wpa_supplicant, and verifies them |
| `[8]` | **CLEANUP / RECOVER** | Cleans up a finished run, or recovers a previous interrupted run from its saved state |
| `[9]` | **DIAGNOSTICS / TROUBLESHOOT** | Read-only diagnostics: environment, tools, backends, interfaces, PHY, rfkill, services, and firmware log |
| `[10]` | **EXIT** | Verified cleanup, then exits |

### What changed in v2.3.2

Compared with the old 1–8 menu in the previous README, v2.3.2 adds and renames:

- **Option [7] RESTORE NETWORK MANAGER** — new, explicit network restore, separate from cleanup.
- **Option [8] CLEANUP / RECOVER** — old Cleanup is now cleanup plus recovery from a saved interrupted run.
- **Option [9] DIAGNOSTICS / TROUBLESHOOT** — new, read-only system and tool check.
- **Option [10] EXIT** — old Exit was option 8, now option 10.
- **Option [6] MASK ATTACK** — moved: it was option 7 in the old README, it is option 6 now, and it is the one option marked not working properly yet.
- **State and recovery throughout** — the script now saves run state, restores only the services it stopped, restores rfkill and regulatory settings, and converts monitor interfaces back to managed instead of deleting an interface it did not create.

---

## Safety, state, and recovery

These are built into v2.3.2, not separate tools:

- **Root check:** the script must run as root (`sudo`). It refuses to run otherwise.
- **Saved state:** run state is saved under `/var/lib/wifi-pwn/state` (with a `/tmp` fallback if that path is not writable). It records the original interface, monitor interface, mode, and which services were stopped by the tool.
- **Cleanup on exit and on signals:** exiting, Ctrl-C, and termination signals all run cleanup: stop child processes, disable monitor mode, restore regulatory and rfkill settings, restore stopped services, and verify a managed interface is present. If cleanup is incomplete, state is kept so option [8] can recover it.
- **Service restore:** only NetworkManager, wpa_supplicant, and networking services that the tool itself stopped are restarted, and only if they were active before. Services it did not stop are left alone.
- **Monitor handling:** an interface already in monitor mode is reused, never duplicated, and cleanup converts it back to managed, never deletes it. A new monitor interface is created only if in-place monitor mode fails.
- **Monitor verification and recovery:** after monitor mode is enabled, the script verifies it can actually receive frames, and retries monitor recovery if the first probe sees nothing.
- **Secure temporary files:** work files go to a private temporary directory with restrictive permissions, and result files are written with restrictive permissions. Temporary work files are removed on clean exit.
- **Interface checks:** interface, PHY, driver, USB, 5 GHz support, and monitor support are reported before use, with VM status reported in diagnostics.

---

## Scan behaviour

- Scan starts at 25 seconds, and the duration grows by 10 seconds on each rescan.
- On a 5 GHz-capable PHY it scans both bands first; otherwise it scans 2.4 GHz on channels 1, 6, and 11.
- If a scan finds nothing, it retries on 2.4 GHz with a fixed channel list and monitor recovery.
- Scan results are de-duplicated by BSSID, and a target can be picked by number or by BSSID. Invalid BSSID or channel values are rejected.

---

## Requirements

- Linux, with Kali Linux / Parrot OS / Debian-based distros as the primary target. Distro and package-manager detection covers apt-get, dnf, pacman, zypper, apk, xbps-install, and eopkg.
- Wireless adapter with **monitor mode** support.
- Root privileges (`sudo`).

### Required tools (checked, installed if missing and available)

`airmon-ng`, `airodump-ng`, `aireplay-ng`, `aircrack-ng`, `awk`, `ip`, `iw`

### Optional tools, by feature

| Tool | Used for |
| --- | --- |
| `iwconfig`, `ethtool` | Interface detection and reporting |
| `hashcat` | Mask attack (option 6, currently not working properly) |
| `hcxpcapngtool`, `cap2hccapx` (`hcxtools`) | Capture-to-hash conversion |
| `john` | John the Ripper CPU fallback for mask attack |
| `clinfo`, PoCL / OpenCL ICD packages | OpenCL backend check and repair for Hashcat |
| `xterm` or another detected terminal | Separate terminal windows for cracking and mask attack |
| `rfkill`, `nmcli`, `systemctl` / OpenRC / runit / SysV tools | rfkill, NetworkManager, and service management, where present |

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

Then choose an option from the menu (options 1–10, as listed above) and follow the on-screen prompts.

Other supported commands:

```bash
sudo ./wifi_pen_test.sh --help
sudo ./wifi_pen_test.sh --version
sudo ./wifi_pen_test.sh --check
```

`--check` runs diagnostics only, without starting the menu.

---

## Usage demo (video)

Watch the full FULL AUTO flow in action, recorded on Kali Linux (2:50):

<video src="wiflpent-usage-demo.mp4" controls width="100%"></video>

[Watch / download the demo video](wiflpent-usage-demo.mp4)

What the video shows, in order:

1. Run `sudo ./wifi_pen_test.sh` and choose option `[1]` FULL AUTO from the menu.
2. Pick the wireless interface (wlan0 in the video) for monitor mode. The tool stops NetworkManager / wpa_supplicant, enables and verifies monitor mode, and recovers if the first probe sees no frames.
3. Scan for nearby networks (25 seconds on the first scan) and select the target from the list.
4. Capture the WPA handshake for the target, with the capture name and handshake verification shown on screen.
5. Restore managed networking after the capture.
6. Prepare the wordlist (rockyou.txt in the video) and crack the capture in a separate terminal with aircrack-ng.
7. The cracked password is saved to a `password_<capture>_<timestamp>.txt` file in the output folder.

> This demo is on a test network the author owns. Use WIFLPENT only on networks you own or have explicit, written permission to test.

---

## Wordlist

Option [5] and FULL AUTO prepare `rockyou.txt` automatically, in this order:

1. Reuse an existing `rockyou.txt` in the output folder, if present and non-empty.
2. Find it in the system wordlist locations (Kali/Parrot `wordlists`, or Seclists on other distros), including `.gz` and `.tar.gz` forms.
3. Install the `wordlists` or `seclists` package if available, then look again.
4. If still not found, ask for a wordlist path.

---

## Outputs

The output folder is chosen in this order, first writable location wins:

1. `Desktop/WI-FI Pentest` for the sudo user, if detectable
2. `~/.local/share/wifi-pwn`
3. `~/WI-FI Pentest`
4. `/root/WI-FI Pentest`
5. `/tmp/WI-FI Pentest`

Files in the output folder include:

- `*.cap` — Captured WPA handshake
- `*.hccapx` / `*.22000` — Hashcat-ready hash, when conversion succeeds
- `password_<capture>_<timestamp>.txt` — Cracked password from a wordlist run
- `password_mask_<timestamp>.txt` — Mask attack result file, when mask attack works
- `rockyou.txt` — Wordlist prepared by the tool, when it had to extract or install one

---

## Diagnostics (Option [9], read-only)

Diagnostics reports, without changing anything:

- Version, kernel, distro, package manager, and user ID
- Presence of every tool listed above, plus `timeout` and `pgrep`
- Hashcat backend status and registered OpenCL ICD files, plus `clinfo` output when available
- Regulatory domain, wireless devices, link state, interface summary, and PHY capabilities
- rfkill state, service manager and service states, `airmon-ng` availability
- Last firmware-related kernel log lines, VM status, and any stale saved run state

---

## Disclaimer

This tool is for AUTHORIZED security testing and educational purposes ONLY. Unauthorized use against networks you do not own or have explicit permission to test is ILLEGAL.

The authors assume NO LIABILITY and are NOT RESPONSIBLE for any misuse or damage caused by this program.

Use WIFLPENT only on networks you own or have explicit, written permission to test.

---

## License

MIT License — Copyright (c) 2026 Team UNIT-61398. See the `LICENSE` file for the full license text.
